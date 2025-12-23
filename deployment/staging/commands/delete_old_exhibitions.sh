#!/usr/bin/env bash
SECONDS=0
# shellcheck disable=SC2034
export DJANGO_SETTINGS_MODULE=museumsportal.settings.staging
PROJECT_PATH=/var/webapps/museumsportal
CRON_LOG_FILE=${PROJECT_PATH}/logs/delete_old_exhibitions.log
script_errors=0

cd ${PROJECT_PATH} || exit 1
# shellcheck disable=SC1091
source venv/bin/activate
cd ${PROJECT_PATH}/project/museumsportal || exit 1

# Check if date parameter is set, if so pass it to the command
if [ -n "$1" ]; then
    echo "Delete old exhibitions with date parameter $1" > ${CRON_LOG_FILE}
    date >> ${CRON_LOG_FILE}
    python manage.py delete_old_exhibitions --date="$1" --verbosity=2 --traceback --settings=museumsportal.settings.staging >> ${CRON_LOG_FILE} 2>&1
else
    echo "Delete old exhibitions" > ${CRON_LOG_FILE}
    date >> ${CRON_LOG_FILE}
    python manage.py delete_old_exhibitions --verbosity=2 --traceback --settings=museumsportal.settings.staging >> ${CRON_LOG_FILE} 2>&1
fi

function_exit_code=$?
if [[ $function_exit_code -ne 0 ]]; then
    {
        echo "<<<<<<<<<<<<"
        echo "Function exit code is non-zero ($function_exit_code) for command delete_old_exhibitions"
        echo ">>>>>>>>>>>>"
        script_errors=$((script_errors + 1))
    } >> "${CRON_LOG_FILE}" 2>&1
else
    echo "No error running command delete_old_exhibitions" >> "${CRON_LOG_FILE}" 2>&1
fi

echo "Finished." >> ${CRON_LOG_FILE}
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed." >> ${CRON_LOG_FILE}

if [[ $script_errors -ne 0 ]]; then
    {
        echo "<<<<<<<<<<<<"
        echo "Script encountered $script_errors errors during execution"
        echo ">>>>>>>>>>>>"
    } >> "${CRON_LOG_FILE}" 2>&1
fi

exit $script_errors
