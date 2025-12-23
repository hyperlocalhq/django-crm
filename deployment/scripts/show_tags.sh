#!/bin/bash

# Show available Ansible tags
# Usage: ./show_tags.sh

echo "📋 Available Ansible Tags:"
echo ""
echo "🏷️  System & Infrastructure:"
echo "   provision     - Initial server setup tasks"
echo "   system        - System packages, users, directories"
echo "   security      - SSH, fail2ban, firewall"
echo "   database      - PostgreSQL setup"
echo "   python        - Python/pyenv setup"
echo "   web           - Nginx, SSL certificates"
echo "   monitoring    - Prometheus exporters, Grafana Promtail"
echo ""
echo "🏷️  Application:"
echo "   app           - Application deployment"
echo "   deploy        - Tasks that run on every deployment"
echo "   config        - Configuration file updates"
echo ""
echo "💡 Usage Examples:"
echo "   ./deploy.sh staging --tags app                    # Deploy only app tasks"
echo "   ./deploy.sh production --tags web,config          # Deploy web and config"
echo "   ./provision.sh staging --tags=system,security     # Setup system and security"
echo "   ./provision.sh production --tags database         # Setup database only"