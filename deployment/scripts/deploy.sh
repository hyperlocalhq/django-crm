#!/bin/bash

# Quick deployment to any environment
# Usage: ./deploy.sh [staging|production] [--secrets path/to/secrets.yml] [ansible-playbook-options...]

set -e

# Function to show help
show_help() {
    echo "🚀 Deploy Script Help"
    echo "===================="
    echo ""
    echo "Usage: ./deploy.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
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
    echo "    --tags tag1,tag2       Deploy only specific services/components"
    echo "    --force-handlers       Force handlers to run even if tasks don't change"
    echo "    --diff                 Show differences in files"
    echo "    --check                Dry run mode"
    echo "    -v, -vv, -vvv          Verbose output (1-3 levels)"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh staging                              # Deploy all services to staging"
    echo "  ./deploy.sh production                           # Deploy all services to production"
    echo "  ./deploy.sh staging --tags app                   # Deploy only app to staging"
    echo "  ./deploy.sh production --tags web,config         # Deploy web and config to production"
    echo "  ./deploy.sh staging --secrets ../secrets.yml     # Deploy to staging with local secrets"
    echo "  ./deploy.sh staging --tags app --force-handlers  # Deploy app with forced handler execution"
    echo "  ./deploy.sh staging --check --diff               # Dry run with diff output"
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
    echo "Usage: ./deploy.sh staging|production [--secrets path/to/secrets.yml] [ansible-playbook-options...]"
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
    CONFIRM_REQUIRED=true
else
    EMOJI="🚀"
    CONFIRM_REQUIRED=false
fi

echo "$EMOJI Quick deploy to $(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')..."
echo "This will update the application code and restart services."
echo ""

# Show current git branch for context
if command -v git &> /dev/null && [ -d .git ]; then
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo "📝 Current local branch: $current_branch"
    if [ "$ENVIRONMENT" == "production" ]; then
        echo "⚠️  Make sure you're on the correct branch for production!"
    fi
    echo ""
fi

# Confirmation for production only
if [ "$CONFIRM_REQUIRED" == true ]; then
    read -p "Are you sure you want to deploy to PRODUCTION? (y/n): " confirm
    if [ "$confirm" != "$CONFIRM_TEXT" ]; then
        echo "❌ Production deployment cancelled."
        exit 1
    fi
fi

# Build ansible command
ANSIBLE_CMD="ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml deploy.yml"

# Add any additional ansible arguments
if [ ${#ANSIBLE_ARGS[@]} -gt 0 ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD ${ANSIBLE_ARGS[*]}"
    echo "📋 Running deployment for $ENVIRONMENT with options: ${ANSIBLE_ARGS[*]}..."
else
    echo "📋 Running deployment for $ENVIRONMENT..."
fi

# Execute ansible command
$ANSIBLE_CMD

echo ""
echo "✅ $ENVIRONMENT deployment completed!"
