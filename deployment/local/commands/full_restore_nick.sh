#!/usr/bin/env zsh

SECONDS=0
PROJECT=museumsportal

helpFunction()
{
   echo ""
   echo "Usage: ./full_restore_nick.sh -e staging|production"
   printf "\t-e The server from which to download db."
   exit 1 # Exit script after printing help
}

while getopts ":e:" opt; do
   case ${opt} in
      e ) ENV=$OPTARG ;;  # $OPTARG holds the value of the -e paramanter
      \? ) helpFunction ;; # print helpFunction in case parameter is not "e"
      : ) helpFunction ;;  # print helpFunction in case parameter is "e" but without a value
   esac
done



##### DOWNLOAD
CURRENT_DIR=$(dirname "$0")
BACKUP_PATH=${CURRENT_DIR}/../data/latest.backup

echo "Downloading ${ENV} database backup..."
date

scp ${PROJECT}-${ENV}:/var/webapps/${PROJECT}/db_backups/latest.backup.gz ${BACKUP_PATH}.gz
gunzip -f ${BACKUP_PATH}.gz

echo "Finished downloading!"


##### RESTORE
DATABASE=${PROJECT}
USER=nick
PORT=5432

if [ ! -f ${BACKUP_PATH} ]; then
    echo "Backup file not found! Run ./full_restore_nick.sh -e 'staging|production' first."
    exit 1
fi

echo "Restoring ${ENV} database from backup..."
date

echo "Disconnecting..."
psql --username=${USER} --port=${PORT} --dbname=${DATABASE} --command='SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'

echo "Dropping..."
dropdb --username=${USER} --port=${PORT} ${DATABASE}

echo "Recreating..."
createdb --username=${USER} --port=${PORT} ${DATABASE}

echo "Restoring..."
psql --username=${USER} --port=${PORT} --dbname=${DATABASE} --file=${BACKUP_PATH}

echo "Finished restoring!"

PROJECT_PATH=$HOME/django_projects/studio38/${PROJECT}/
cd ${PROJECT_PATH} || exit 1
# shellcheck source=src/util.sh
source .venv/bin/activate
python manage.py resetsuperuser --settings=${PROJECT}.settings.local_nick

duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."
