#!/bin/bash

# Full server setup for any environment
# Usage: ./provision.sh [staging|production] [--secrets path/to/secrets.yml] [ansible-playbook-options...]

set -e

# Function to show help
show_help() {
    echo "🚨 Provision Script Help"
    echo "========================"
    echo ""
    echo "Usage: ./provision.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
    echo ""
    echo "Arguments:"
    echo "  staging|production       Target environment (required)"
    echo ""
    echo "Options:"
    echo "  --secrets path/to/file   Emergency fallback: load secrets from local file"
    echo "  --secrets=path/to/file   Alternative syntax for secrets"
    echo "  --help, -h               Show this help message"
    echo ""
    echo "Ansible Options:"
    echo "  All other parameters are passed directly to ansible-playbook."
    echo "  Common examples:"
    echo "    --tags tag1,tag2       Provision only specific components"
    echo "    --force-handlers       Force handlers to run even if tasks don't change"
    echo "    --diff                 Show differences in files"
    echo "    --check                Dry run mode"
    echo "    -v, -vv, -vvv          Verbose output (1-3 levels)"
    echo ""
    echo "Examples:"
    echo "  ./provision.sh staging                              # Full server provisioning for staging"
    echo "  ./provision.sh production                           # Full server provisioning for production"
    echo "  ./provision.sh staging --tags system                # Setup only system components for staging"
    echo "  ./provision.sh production --tags web,ssl            # Setup web server and SSL for production"
    echo "  ./provision.sh staging --secrets ../secrets.yml     # Provision staging with local secrets"
    echo "  ./provision.sh staging --tags web --check --diff    # Dry run web provisioning with diff output"
    echo ""
    echo "⚠️  Emergency Secrets:"
    echo "  The --secrets flag is for emergency use when Infisical is down."
    echo "  It requires a complete and valid secrets.yml file with all necessary variables."
    echo ""
    # Execute show_tags.sh and include its output
    if [ -f "./show_tags.sh" ]; then
        "./show_tags.sh"
    else
        echo "⚠️  show_tags.sh not found - cannot display available tags"
    fi
}

# Function to show error and exit
show_error() {
    echo "❌ Error: $1"
    echo "Usage: ./provision.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
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
        echo "❌ Secrets file not found: $SECRETS_PATH"
        exit 1
    fi
    
    # Export environment variable for the plugin
    export ANSIBLE_EMERGENCY_SECRETS_PATH="$SECRETS_PATH"
    echo "🚨 Emergency mode: Using local secrets file: $SECRETS_PATH"
    echo ""
fi

# Set environment-specific variables
if [ "$ENVIRONMENT" == "production" ]; then
    EMOJI="🚨"
else
    EMOJI="🚀"
fi

echo "$EMOJI $(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]') FULL SETUP $EMOJI"
echo ""

# Show current git branch for context
if command -v git &> /dev/null && [ -d .git ]; then
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo "📝 Current local branch: $current_branch"
    echo ""
fi

read -p "Are you SURE you want to run FULL SETUP on $ENVIRONMENT? (type '$CONFIRM_TEXT'): " confirm
if [ "$confirm" != "$CONFIRM_TEXT" ]; then
    echo "❌ $ENVIRONMENT setup cancelled."
    exit 1
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml provision.yml"

# Add any additional ansible arguments
if [ ${#ANSIBLE_ARGS[@]} -gt 0 ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD ${ANSIBLE_ARGS[*]}"
    echo "📋 Running provisioning for $ENVIRONMENT with options: ${ANSIBLE_ARGS[*]}..."
else
    echo "📋 Running full provisioning for $ENVIRONMENT..."
fi

# Execute ansible command
$ANSIBLE_CMD

echo ""
echo "✅ Full $ENVIRONMENT setup completed successfully!"
