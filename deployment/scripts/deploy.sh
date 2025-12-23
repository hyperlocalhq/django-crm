#!/bin/bash
# Django CRM Quick Deployment
# Usage: ./deploy.sh staging [ansible-options...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

if [ -z "$1" ]; then
    echo "Usage: ./deploy.sh staging|production [ansible-options...]"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh staging"
    echo "  ./deploy.sh staging --tags app"
    echo "  ./deploy.sh staging --check --diff"
    exit 1
fi

ENVIRONMENT=$1
shift

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    echo "Error: Invalid environment '$ENVIRONMENT'. Use 'staging' or 'production'."
    exit 1
fi

cd "$ANSIBLE_DIR"

echo "=== Deploying to $ENVIRONMENT ==="
ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml deploy.yml "$@"
echo "=== Done ==="
