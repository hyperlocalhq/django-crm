#!/usr/bin/env bash

# Get the directory where this script resides
CMD_DIR="$(dirname "$(readlink -f "$0")")"

# Default values
BACKUP_TYPE="scheduled"  # or "immediate"
SECONDS=0
script_errors=0

# Function to display usage information specific to backup_db.sh
print_backup_usage() {
    echo "Usage: $0 [OPTIONS] -p=PROJECT -e=ENVIRONMENT"
    echo "Backup Options:"
    echo "  -t, --type=TYPE            Backup type: 'scheduled' (default) or 'immediate'"
    echo ""
    echo "Required Project Options:"
    echo "  -p, --project=PROJECT      Specify the project name"
    echo "  -e, --environment=ENV      Specify the environment"
    echo ""
    echo "Additional Options:"
    echo "  -d, --rotation-days=DAYS   Specify the log rotation days (default: 60)"
    echo "  -h, --help                 Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 -t=immediate -p=myproject -e=production"
}

# Check if no arguments provided and show backup usage
if [[ $# -eq 0 ]]; then
    print_backup_usage
    exit 1
fi

# Parse the backup type before sourcing base.sh
while [[ $# -gt 0 ]]; do
    case $1 in
        -t=*|--type=*)
            BACKUP_TYPE="${1#*=}"
            if [[ "${BACKUP_TYPE}" != "scheduled" && "${BACKUP_TYPE}" != "immediate" ]]; then
                echo "Error: Invalid backup type. Must be 'scheduled' or 'immediate'" >&2
                exit 1
            fi
            ;;
        -h|--help)
            print_backup_usage
            exit 0
            ;;
        *)
            # Let base.sh handle other arguments
            REMAINING_ARGS+=("$1")
            ;;
    esac
    shift
done

# Source base.sh and pass only the remaining arguments to it
source "${CMD_DIR}/base.sh" "${REMAINING_ARGS[@]}"

# Default paths setup based on backup type
setup_paths() {
    if [[ "${BACKUP_TYPE}" == "scheduled" ]]; then
        WEEK_DATE=$(LC_ALL=en_US.UTF-8 date +"%w-%A")
        LOG_DIR="${PROJECT_PATH}/logs/backup_db_scheduled"
        BACKUP_PATH="${PROJECT_PATH}/db_backups/${WEEK_DATE}.backup"
    else
        LOG_DIR="${PROJECT_PATH}/logs/backup_db_immediate"
        BACKUP_PATH="${PROJECT_PATH}/db_backups/${DATE_FORMAT}.backup"
    fi
    CRON_LOG_FILE="${LOG_DIR}/${DATE_FORMAT}.log"
    LATEST_PATH="${PROJECT_PATH}/db_backups/latest.backup"
    mkdir -p "${LOG_DIR}"
}

# Setup paths based on backup type
setup_paths

# Activate virtual environment and change directory
export DJANGO_SETTINGS_MODULE="${PROJECT}.settings.${ENVIRONMENT}"
source "${PROJECT_PATH}/venv/bin/activate"
cd "${PROJECT_PATH}/project/${PROJECT}" || exit 1

# Rotate logs
find "${LOG_DIR}" -type f -name "*.log" -mtime "+${ROTATION_DAYS}" -delete

# Get database configuration from Django
DATABASE=$(echo "from django.conf import settings; print(settings.DATABASES['default']['NAME'])" | python manage.py shell)
USER=$(echo "from django.conf import settings; print(settings.DATABASES['default']['USER'])" | python manage.py shell)

# Initialize log file
{
    echo "Creating DB Backup"
    date
    echo "Backup type: ${BACKUP_TYPE}"
} > "${CRON_LOG_FILE}"

# Perform database dump
echo "Dump database" >> "${CRON_LOG_FILE}"
pg_dump --format=p --encoding=UTF8 --no-owner --no-privileges --no-comments --file="${BACKUP_PATH}" "${DATABASE}" || exit 1
function_exit_code=$?

if [[ $function_exit_code -ne 0 ]]; then
    {
        echo "<<<<<<<<<<<<"
        echo "Function exit code is non-zero ($function_exit_code) for command pg_dump"
        echo ">>>>>>>>>>>>"
        script_errors=$((script_errors + 1))
    } >> "${CRON_LOG_FILE}" 2>&1
else
    echo "No error running command pg_dump" >> "${CRON_LOG_FILE}" 2>&1
fi

# Compress backup file
gzip --force "${BACKUP_PATH}"
function_exit_code=$?
if [[ $function_exit_code -ne 0 ]]; then
    {
        echo "<<<<<<<<<<<<"
        echo "Function exit code is non-zero ($function_exit_code) for command gzip"
        echo ">>>>>>>>>>>>"
        script_errors=$((script_errors + 1))
    } >> "${CRON_LOG_FILE}" 2>&1
else
    echo "No error running command gzip" >> "${CRON_LOG_FILE}" 2>&1
fi


if [[ "$BACKUP_TYPE" == "scheduled" ]]; then
  # Update latest backup symlink only for scheduled backups
    ln -sf "${BACKUP_PATH}.gz" "${LATEST_PATH}.gz"
    echo "Updated latest.backup symlink" >> "${CRON_LOG_FILE}" 2>&1

    ln -sf "${CRON_LOG_FILE}" "${LOG_DIR}/latest.log"
    echo "Updated latest.log symlink" >> "${CRON_LOG_FILE}" 2>&1
fi

# Log completion
{
    echo "Finished."
    duration=$SECONDS
    echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."

    if [[ $script_errors -ne 0 ]]; then
        echo "<<<<<<<<<<<<"
        echo "Script encountered $script_errors errors during execution"
        echo ">>>>>>>>>>>>"
    fi
} >> "${CRON_LOG_FILE}" 2>&1

exit $script_errors
