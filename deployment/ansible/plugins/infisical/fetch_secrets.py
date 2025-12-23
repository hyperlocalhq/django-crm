#!/usr/bin/env python3
"""
Ansible vars plugin to fetch secrets from Infisical
"""

DOCUMENTATION = """
    name: infisical_secrets
    plugin_type: vars
    short_description: Fetch secrets from Infisical
    description:
        - Retrieves secrets from Infisical and makes them available as Ansible variables
        - Replaces the need for static secrets.yml file
"""

import os
import yaml
import json
import tempfile
import atexit
from pathlib import Path

from ansible.plugins.vars import BaseVarsPlugin
from ansible.utils.display import Display

display = Display()

# Track cache files created during this run for cleanup on exit
_cache_files_to_cleanup = set()


def _cleanup_cache_files():
    """Clean up all cache files when Python exits (regardless of success/failure)"""
    for cache_file in _cache_files_to_cleanup:
        try:
            if os.path.exists(cache_file):
                os.remove(cache_file)
        except Exception:
            pass  # Ignore cleanup errors


# Register the cleanup function to run when Ansible exits
atexit.register(_cleanup_cache_files)

try:
    from infisical_sdk import InfisicalSDKClient

    HAS_INFISICAL = True
except ImportError:
    HAS_INFISICAL = False


class VarsModule(BaseVarsPlugin):
    """Vars plugin to fetch secrets from Infisical"""

    def _get_cache_file(self, project_name, project_specific):
        return os.path.join(
            tempfile.gettempdir(),
            f"ansible_infisical_cache_{project_name}_{project_specific}.json",
        )

    def _is_cache_valid(self, project_name, project_specific):
        """Check if the cache file exists and is within TTL"""
        cache_file = self._get_cache_file(project_name, project_specific)
        return os.path.exists(cache_file)

    def _load_cache(self, project_name, project_specific):
        """Load secrets from the cache file"""
        cache_file = self._get_cache_file(project_name, project_specific)
        try:
            with open(cache_file, "r") as f:
                return json.load(f)
        except Exception as e:
            display.warning(f"Failed to load {cache_file}: {e}")
            return None

    def _save_cache(self, secrets, project_name, project_specific):
        """Save secrets to the cache file"""
        cache_file = self._get_cache_file(project_name, project_specific)
        try:
            with open(cache_file, "w") as f:
                json.dump(secrets, f)
            # Register this cache file for cleanup when Ansible exits
            _cache_files_to_cleanup.add(cache_file)
        except Exception as e:
            display.warning(f"Failed to save cache in {cache_file}: {e}")

    def _resolve_project_name(self, project_name_template, project_name, project_specific):
        """Resolve Ansible template variables in project names"""
        if "{{ project_name }}" in project_name_template and "{{ project_specific }}" in project_name_template:
            return project_name_template.replace("{{ project_name }}", project_name).replace("{{ project_specific }}", project_specific)
        return project_name_template

    def _resolve_credentials_suffix(self, suffix_template, project_name, project_specific):
        """Resolve Ansible template variables in credentials suffix"""
        if "{{ project_name | upper }}" in suffix_template and "{{ project_specific | upper }}" in suffix_template:
            return suffix_template.replace("{{ project_name | upper }}", project_name.upper()).replace("{{ project_specific | upper }}", project_specific.upper())
        return suffix_template

    def _fetch_secrets_from_project(
        self,
        infisical_host,
        client_id,
        client_secret,
        project_slug,
        env,
        secret_path="/"
    ):
        """Fetch secrets from a single Infisical project"""
        try:
            client = InfisicalSDKClient(host=infisical_host)
            auth_data = client.auth.universal_auth.login(
                client_id=client_id,
                client_secret=client_secret,
            )
            if not auth_data:
                raise ValueError(f"Failed to login to Infisical for project {project_slug}")

            secrets = client.secrets.list_secrets(
                project_slug=project_slug,
                environment_slug=env,
                secret_path=secret_path,
            )
            if not secrets:
                display.warning(f"No secrets found in project {project_slug} ({env} environment)")
                return {}

            vars_dict = {}
            for secret in secrets.secrets:
                vars_dict[secret.secretKey] = secret.secretValue

            display.display(msg=f"  Retrieved {len(vars_dict)} secrets from project {project_slug} ({env} environment)")
            return vars_dict

        except Exception as e:
            display.display(
                msg=f"Failed to retrieve secrets from project {project_slug} ({env} environment): {str(e)}",
                color="red",
            )
            return {}

    def get_vars(self, loader, path, entities, cache=True):
        """
        Fetch secrets from Infisical and return as variables
        """
        super().get_vars(loader, path, entities)

        # Check for the emergency secrets file first
        emergency_secrets_path = os.environ.get("ANSIBLE_EMERGENCY_SECRETS_PATH")
        if emergency_secrets_path:
            try:
                display.display(f"🚨 Emergency mode: Loading secrets from {emergency_secrets_path}")
                with open(emergency_secrets_path, "r") as f:
                    secrets_data = yaml.safe_load(f)

                if not secrets_data:
                    raise ValueError("Emergency secrets file is empty or invalid")

                display.display(f"✅ Successfully loaded {len(secrets_data)} secrets from emergency file")
                return secrets_data

            except Exception as e:
                display.error(f"❌ Failed to load emergency secrets from {emergency_secrets_path}: {str(e)}")
                raise e

        if not HAS_INFISICAL:
            display.warning(
                "infisicalsdk is not installed. Skipping Infisical secret retrieval."
            )
            raise ImportError(
                "infisicalsdk is not installed. Use pip install -r requirements.txt"
            )

        try:
            file_path = Path(__file__).parent.parent.parent / "vars" / "appserver_vars.yml"
            with open(file_path, "r") as f:
                data = yaml.safe_load(f)
        except Exception as e:
            display.error(f"Could not read configuration from appserver_vars.yml: {e}")
            raise e

        project_name = data.get("project_name")
        if not project_name:
            display.error("project_name not found in appserver_vars.yml")
            raise ValueError("project_name not found in appserver_vars.yml")

        project_specific = data.get("project_specific")
        if not project_name:
            display.error("project_specific not found in appserver_vars.yml")
            raise ValueError("project_specific not found in appserver_vars.yml")

        infisical_config = data.get("infisical_config")
        if infisical_config:
            infisical_host = infisical_config.get("host")
            infisical_projects = infisical_config.get("projects")
            if not infisical_host:
                display.error("infisical_host not found in appserver_vars.yml")
                raise ValueError("infisical_host not found in appserver_vars.yml")
            if not infisical_projects:
                display.error("infisical_projects not found in appserver_vars.yml")
                raise ValueError("infisical_projects not found in appserver_vars.yml")
        else:
            display.error("infisical_config not found in appserver_vars.yml")
            raise ValueError("infisical_config not found in appserver_vars.yml")

        # Resolve project names and credentials suffixes with template variables
        resolved_projects = []
        for project_config in infisical_projects:
            resolved_name = self._resolve_project_name(project_config["name"], project_name, project_specific)
            credentials_suffix = project_config.get("credentials_suffix", project_name.upper())
            resolved_suffix = self._resolve_credentials_suffix(credentials_suffix, project_name, project_specific)
            resolved_projects.append({
                "name": resolved_name,
                "priority": project_config.get("priority", 1),
                "path": project_config.get("path", "/"),
                "credentials_suffix": resolved_suffix,
            })

        # Sort projects by priority (lower number = higher priority)
        resolved_projects.sort(key=lambda x: x["priority"])

        # Determine environment from inventory path
        env = "prod"  # default
        if path:
            path_str = str(path)
            if "staging" in path_str:
                env = "staging"
            elif "production" in path_str:
                env = "prod"
            elif "elasticsearch" in path_str:
                env = "prod"

        cache_file = self._get_cache_file(project_name, project_specific)

        # Check file cache first
        if self._is_cache_valid(project_name, project_specific):
            cached_secrets = self._load_cache(project_name, project_specific)
            if cached_secrets:
                return cached_secrets

        try:
            # Fetch secrets from all configured projects
            merged_secrets = {}
            total_secrets_count = 0

            # Process projects in priority order (already sorted)
            for project_config in resolved_projects:
                project_slug = project_config["name"]
                priority = project_config["priority"]
                secret_path = project_config["path"]
                credentials_suffix = project_config["credentials_suffix"]

                # Get credentials for this specific project
                client_id = None
                client_secret = None

                # Try to read from secrets.yml first
                try:
                    file_path = Path(__file__).parent.parent.parent / "appserver_secrets.yml"
                    with open(file_path, "r") as f:
                        secrets_data = yaml.safe_load(f)
                        client_id = secrets_data.get(f"infisical_client_id_{credentials_suffix.lower()}")
                        client_secret = secrets_data.get(f"infisical_client_secret_{credentials_suffix.lower()}")
                except Exception:
                    pass  # Will try environment variables

                # Fall back to environment variables if secrets.yml values are missing
                if not client_id:
                    client_id = os.environ.get(f"INFISICAL_CLIENT_ID_{credentials_suffix}")
                if not client_secret:
                    client_secret = os.environ.get(f"INFISICAL_CLIENT_SECRET_{credentials_suffix}")

                if not all([client_id, client_secret]):
                    display.warning(
                        f"Credentials not found for project '{project_slug}' (suffix: {credentials_suffix}). "
                        f"client_id={bool(client_id)}, client_secret={bool(client_secret)}. Skipping."
                    )
                    raise ValueError(
                        f"Credentials not found for project '{project_slug}' (suffix: {credentials_suffix}). "
                        f"client_id={bool(client_id)}, client_secret={bool(client_secret)}."
                    )

                display.display(msg=f"Fetching secrets from project '{project_slug}' (priority: {priority})")
                project_secrets = self._fetch_secrets_from_project(
                    infisical_host=infisical_host,
                    client_id=client_id,
                    client_secret=client_secret,
                    project_slug=project_slug,
                    env=env,
                    secret_path=secret_path,
                )

                # Merge secrets - higher priority (lower number) projects override lower priority ones
                # Since we process in priority order, later projects should NOT override earlier ones
                for key, value in project_secrets.items():
                    if key not in merged_secrets:
                        merged_secrets[key] = value
                total_secrets_count += len(project_secrets)

            # Validate that secrets were retrieved
            if not merged_secrets:
                raise ValueError("No secrets retrieved from any Infisical project")

            # Cache the results
            self._save_cache(merged_secrets, project_name, project_specific)

            display.display(
                msg=f"Retrieved {len(merged_secrets)} unique secrets from {len(resolved_projects)} projects ({total_secrets_count} total secrets) - cached for future use",
                color="green",
            )
            return merged_secrets

        except Exception as e:
            display.error(f"Failed to retrieve secrets from Infisical: {str(e)}")
            raise e
