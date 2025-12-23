#!/usr/bin/env bash
CURRENT_DIR=$(dirname "$0")
cd $CURRENT_DIR
BACKUP_PATH=$CURRENT_DIR/data/latest.backup

psql --username=postgres --dbname=museumsportal --command='SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
dropdb --username=postgres museumsportal
createdb --username=museumsportal museumsportal
cd ../../
source venv/bin/activate

## database user must be superuser and created like:
## createuser --superuser --password museumsportal

gzcat ${BACKUP_PATH}.gz | python manage.py dbshell --settings=museumsportal.settings.local

## Restoring alternative below:

#DATABASE=$(echo "from django.conf import settings; print(settings.DATABASES['default']['NAME'])" | python manage.py shell --settings=museumsportal.settings.local)
#PORT=5432
#USER=$(echo "from django.conf import settings; print(settings.DATABASES['default']['USER'])" | python manage.py shell --settings=museumsportal.settings.local)
#PASSWORD=$(echo "from django.conf import settings; print(settings.DATABASES['default']['PASSWORD'])" | python manage.py shell --settings=museumsportal.settings.local)
#gunzip -fk ${BACKUP_PATH}.gz
#psql -v ON_ERROR_STOP=1 --username=${USER} --port=${PORT} --dbname=${DATABASE} --file=${BACKUP_PATH}
