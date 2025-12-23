#!/usr/bin/env bash
set -eo pipefail  # Exit on error, pipefail

# Get the directory where this script resides
CMD_DIR="$(dirname "$(readlink -f "$0")")"

# Construct path to base.sh by going up one level and then back down
source "${CMD_DIR}/base.sh"

# Validate required arguments
if [[ -z "${COMMAND}" ]]; then
    echo "Error: Missing required arguments" >&2
    print_usage
    exit 1
fi

SECONDS=0
LOG_DIR="${PROJECT_PATH}/logs/${COMMAND}"
CRON_LOG_FILE="${LOG_DIR}/${DATE_FORMAT}.log"
LATEST_LOG_SYMLINK="${LOG_DIR}/latest.log"
script_errors=0

# Create log directory and start logging
mkdir -p "${LOG_DIR}"
exec &> >(tee -a "${CRON_LOG_FILE}")

echo "Running command: ${COMMAND}"
echo "Additional arguments: ${ARGS}"
date

# Rotate logs
find "${LOG_DIR}" -type f -name "*.log" -mtime "+${ROTATION_DAYS}" -delete

# Navigate to the project directory
cd "${PROJECT_PATH}" || { echo "Error: Unable to change to project directory" >&2; exit 1; }
# shellcheck disable=SC1091
source venv/bin/activate || { echo "Error: Unable to activate virtual environment" >&2; exit 1; }
cd "${PROJECT_PATH}/project/${PROJECT}" || { echo "Error: Unable to change to project subdirectory" >&2; exit 1; }

# Run the command
if ! python manage.py "${COMMAND}" ${ARGS} --verbosity=2 --traceback --settings="${PROJECT}.settings.${ENVIRONMENT}"; then
    echo "<<<<<<<<<<<<"
    echo "Error: Command execution failed"
    echo ">>>>>>>>>>>>"
    script_errors=$((script_errors + 1))
else
    echo "Command ${COMMAND} executed successfully"
fi

# Finish logging
echo "Finished."
duration=${SECONDS}
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."

if [[ ${script_errors} -ne 0 ]]; then
    echo "<<<<<<<<<<<<"
    echo "Script encountered ${script_errors} errors during execution"
    echo ">>>>>>>>>>>>"
fi

# Create a symlink to the latest log file
ln -sf "${CRON_LOG_FILE}" "${LATEST_LOG_SYMLINK}"

exit ${script_errors}
