#!/usr/bin/env zsh

_GROUP="▶️ "
_ENDGROUP=""
_BOLD="$(tput bold)"
_COLOR_GREEN="\033[0;32m"
_COLOR_BLUE="\033[0;34m"
_COLOR_RED="\033[0;31m"
_COLOR_YELLOW="\033[0;33m"
_NC="\033[0m"

_PROJECT=museumsportal

_SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
_BACKUP_PATH=$(cd ${_SCRIPT_DIR}/../data && pwd)

function display_help() {
   echo "${_BOLD}Script to restore databases${_NC}"
   echo
   echo "${_COLOR_YELLOW}Usage:${_NC}"
   echo "  ./full_restore_iraklis.sh <remote>"
   echo
   echo "${_COLOR_YELLOW}Arguments:${_NC}"
   echo "  ${_COLOR_GREEN}remote${_NC}    The remote host name from which you download the database backup"
   exit 1
}

# Parses secrets.json and returns the value of a given key
# requires `jq` package to be installed on the system (e.g apt install jq)
function get_secret {
   local secrets_dir=$(cd ${_SCRIPT_DIR}/../../../${_PROJECT}/settings && pwd)
   echo $(cat ${secrets_dir}/secrets.json | jq -r ".$1")
}

function run_docker_postgis() {
   local database_password=$(get_secret DATABASE_PASSWORD)

   local docker_database_network=${HYLO_DOCKER_POSTGRES_NETWORK}

   docker run -it --rm \
      --network="${docker_database_network}" \
      -e PGPASSWORD=${database_password} \
      -v "${_BACKUP_PATH}:/backup" \
      postgis/postgis:16-3.4 \
      "$@"
}

function main() {
   local database_user=$(get_secret DATABASE_USER)
   local database_name=$(get_secret DATABASE_NAME)

   local docker_database_host=${HYLO_DOCKER_POSTGRES_HOST}
   local docker_database_port=${HYLO_DOCKER_POSTGRES_PORT}


   if [ $# -gt 0 ]; then
      # Create a temporary file to store the error log
      errorlog=$(mktemp)
      trap 'rm -f "$errorlog"' EXIT

      echo "${_GROUP}Downloading database backup from ${_BOLD}$1${_NC}..."

      echo "Downloading..."
      if ! scp "$1":/var/webapps/${_PROJECT}/db_backups/latest.backup.gz ${_BACKUP_PATH}/latest.backup.gz 2>"$errorlog"; then
         echo "${_COLOR_RED}Failed to download database backup; error log follows:${_NC}"
         cat "$errorlog" | grep --color=ALWAYS '.*'
         exit 1
      fi

      echo "Unzipping..."
      gunzip -f ${_BACKUP_PATH}/latest.backup.gz

      echo "${_COLOR_GREEN}Database backup downloaded succesfully${_NC}"
      echo "${_ENDGROUP}"

      echo "${_GROUP}Restoring ${_BOLD}${database_name}${_NC} database..."

      echo "Disconnecting..."
      output=$(run_docker_postgis psql \
         --host=${docker_database_host} \
         --port=${docker_database_port} \
         --username=${database_user} \
         --dbname=${database_name} \
         --command='SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();')
      # Check if the command failed
      if [[ 0 -ne $? ]]; then
         echo "${_COLOR_RED}Something went wrong; error log follows:${_NC}"
         echo "${_COLOR_RED}$output${_NC}"
         EXIT 1
      fi

      echo "Dropping..."
      run_docker_postgis dropdb \
         --host=${docker_database_host} \
         --port=${docker_database_port} \
         --username=${database_user} \
         ${database_name}

      echo "Recreating..."
      run_docker_postgis createdb \
         --host=${docker_database_host} \
         --port=${docker_database_port} \
         --username=${database_user} \
         ${database_name}

      echo "Restoring..."
      output=$(run_docker_postgis psql \
         --host=${docker_database_host} \
         --port=${docker_database_port} \
         --username=${database_user} \
         --dbname=${database_name} \
         --file="/backup/latest.backup")
      # Check if the command failed
      if [[ 0 -ne $? ]]; then
         echo "${_COLOR_RED}Something went wrong; error log follows:${_NC}"
         echo "${_COLOR_RED}$output${_NC}"
         exit 1
      fi

      echo "${_COLOR_GREEN}Database restored succesfully${_NC}"
      echo "${_ENDGROUP}"

      echo "${_GROUP}Reset superuser${_NC}..."
      python manage.py resetsuperuser --settings=${_PROJECT}.settings.local_iraklis
      echo "${_COLOR_GREEN}Superuser reset succesfully${_NC}"
      echo "${_ENDGROUP}"
   else
      display_help
   fi
}

main "$@"
