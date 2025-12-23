#!/bin/bash
# Django CRM Full Server Provisioning
# Usage: ./provision.sh staging [ansible-options...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

if [ -z "$1" ]; then
    echo "Usage: ./provision.sh staging|production [ansible-options...]"
    echo ""
    echo "This performs FULL server setup:"
    echo "  - System packages & user"
    echo "  - Security (firewall, fail2ban)"
    echo "  - PostgreSQL database"
    echo "  - Python & virtualenv"
    echo "  - Nginx, Gunicorn, SSL"
    echo "  - Django CRM deployment"
    echo ""
    echo "Examples:"
    echo "  ./provision.sh staging"
    echo "  ./provision.sh staging --check --diff"
    exit 1
fi

ENVIRONMENT=$1
shift

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    echo "Error: Invalid environment '$ENVIRONMENT'. Use 'staging' or 'production'."
    exit 1
fi

cd "$ANSIBLE_DIR"

echo "=== Provisioning $ENVIRONMENT server ==="
echo "WARNING: This will perform full server setup!"
read -p "Continue? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Cancelled."
    exit 1
fi

ansible-playbook -i inventories/$ENVIRONMENT/hosts.yml provision.yml "$@"
echo "=== Done ==="
