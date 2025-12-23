#!/usr/bin/env bash

# Get the directory where this script resides
CURRENT_DIR=$(dirname "$0")

# Execute the backup_db.sh script with staging-specific parameters
"${CURRENT_DIR}/backup_db.sh" --type=immediate --project=museumsportal --environment=staging "$@"

