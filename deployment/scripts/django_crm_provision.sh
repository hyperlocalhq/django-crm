#!/bin/bash

# Django CRM Full Server Provisioning Script
# Usage: ./django_crm_provision.sh [staging|production] [--secrets path/to/secrets.yml] [ansible-playbook-options...]

set -e

# Function to show help
show_help() {
    echo "Django CRM Provision Script"
    echo "============================"
    echo ""
    echo "Usage: ./django_crm_provision.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
    echo ""
    echo "This script performs FULL SERVER PROVISIONING including:"
    echo "  - System packages and users"
    echo "  - Security (firewall, fail2ban, SSH hardening)"
    echo "  - PostgreSQL database"
    echo "  - Python environment (uv + venv)"
    echo "  - Nginx, Gunicorn, Memcached"
    echo "  - SSL certificates (Let's Encrypt)"
    echo "  - Django CRM application deployment"
    echo ""
    echo "Arguments:"
    echo "  staging|production       Target environment (required)"
    echo ""
    echo "Options:"
    echo "  --secrets path/to/file   Emergency fallback: load secrets from local file"
    echo "  --secrets=path/to/file   Alternative syntax for secrets"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./django_crm_provision.sh staging                           # Full provision to staging"
    echo "  ./django_crm_provision.sh staging --secrets ../secrets.yml  # Provision with local secrets"
    echo "  ./django_crm_provision.sh staging --check --diff            # Dry run with diff output"
}

# Function to show error and exit
show_error() {
    echo "Error: $1"
    echo "Usage: ./django_crm_provision.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
    echo "Use --help for more information"
    exit 1
}

# Parse command line arguments
ENVIRONMENT=""
SECRETS_PATH=""
ANSIBLE_ARGS=()

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_error "Environment parameter required"
fi

# Parse first argument (environment)
case $1 in
    --help|-h)
        show_help
        exit 0
        ;;
    staging|production)
        ENVIRONMENT=$1
        shift
        ;;
    --secrets|--secrets=*)
        show_error "Environment parameter must be specified first"
        ;;
    *)
        show_error "Invalid environment '$1'. Valid environments: staging, production"
        ;;
esac

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --secrets)
            if [ -z "$2" ]; then
                show_error "--secrets requires a value"
            fi
            SECRETS_PATH="$2"
            shift 2
            ;;
        --secrets=*)
            SECRETS_PATH="${1#*=}"
            if [ -z "$SECRETS_PATH" ]; then
                show_error "--secrets requires a value"
            fi
            shift
            ;;
        *)
            # All other arguments are passed to ansible-playbook
            ANSIBLE_ARGS+=("$1")
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
CONFIRM_TEXT="y"

cd "$ANSIBLE_DIR"

# Handle emergency secrets if provided
if [ -n "$SECRETS_PATH" ]; then
    # Convert to absolute path if relative
    if [[ "$SECRETS_PATH" != /* ]]; then
        SECRETS_PATH="$SCRIPT_DIR/$SECRETS_PATH"
    fi

    # Check if secrets file exists
    if [ ! -f "$SECRETS_PATH" ]; then
        echo "Secrets file not found: $SECRETS_PATH"
        exit 1
    fi

    # Export environment variable for the plugin
    export ANSIBLE_EMERGENCY_SECRETS_PATH="$SECRETS_PATH"
    echo "Emergency mode: Using local secrets file: $SECRETS_PATH"
    echo ""
fi

echo "=========================================="
echo "  Django CRM FULL SERVER PROVISIONING"
echo "  Environment: $(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"
echo "=========================================="
echo ""
echo "WARNING: This will perform FULL SERVER SETUP including:"
echo "  - Install system packages"
echo "  - Configure security (firewall, fail2ban)"
echo "  - Setup PostgreSQL database"
echo "  - Install Python and create virtual environment"
echo "  - Configure Nginx, Gunicorn, Memcached"
echo "  - Setup SSL certificates"
echo "  - Deploy Django CRM application"
echo ""

# Always require confirmation for provisioning
read -p "Are you sure you want to provision $ENVIRONMENT? (y/n): " confirm
if [ "$confirm" != "$CONFIRM_TEXT" ]; then
    echo "Provisioning cancelled."
    exit 1
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook -i inventories/django-crm-$ENVIRONMENT/hosts.yml django_crm_provision.yml"

# Add any additional ansible arguments
if [ ${#ANSIBLE_ARGS[@]} -gt 0 ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD ${ANSIBLE_ARGS[*]}"
    echo "Running Django CRM provisioning for $ENVIRONMENT with options: ${ANSIBLE_ARGS[*]}..."
else
    echo "Running Django CRM provisioning for $ENVIRONMENT..."
fi
echo ""

# Execute ansible command
$ANSIBLE_CMD

echo ""
echo "=========================================="
echo "  Django CRM $ENVIRONMENT PROVISIONING COMPLETE!"
echo "=========================================="
