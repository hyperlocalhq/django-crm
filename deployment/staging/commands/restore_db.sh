#!/usr/bin/env bash
SECONDS=0
PROJECT_PATH=/var/webapps/museumsportal
LATEST_PATH=${PROJECT_PATH}/db_backups/latest.backup
export DJANGO_SETTINGS_MODULE=museumsportal.settings.staging

source ${PROJECT_PATH}/venv/bin/activate
cd ${PROJECT_PATH}/project/museumsportal || exit 1

DATABASE=$(echo "from django.conf import settings; print(settings.DATABASES['default']['NAME'])" | python manage.py shell)
USER=$(echo "from django.conf import settings; print(settings.DATABASES['default']['USER'])" | python manage.py shell)
PASSWORD=$(echo "from django.conf import settings; print(settings.DATABASES['default']['PASSWORD'])" | python manage.py shell)
HOST=$(echo "from django.conf import settings; print(settings.DATABASES['default']['HOST'])" | python manage.py shell)
PORT=$(echo "from django.conf import settings; print(settings.DATABASES['default']['PORT'])" | python manage.py shell)

export PGPASSWORD=$PASSWORD
export PGCLIENTENCODING=UTF8

psql --username=$USER --host=$HOST --port=$PORT --dbname=$DATABASE --command='SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();'
dropdb --username=$USER --host=$HOST --port=$PORT $DATABASE

echo "Creating database from db_template_with_extensions (includes PostGIS and pg_stat_statements extensions)..."
createdb --username=$USER --host=$HOST --port=$PORT --encoding=UTF8 --template=db_template_with_extensions $DATABASE

echo "Restoring database..."
zcat "${LATEST_PATH}.gz" | psql --username=$USER --host=$HOST --port=$PORT --dbname=$DATABASE --variable=ON_ERROR_STOP=0 --quiet 2>&1 | grep -v -E "(no privileges were granted for|must be owner of extension)"

unset PGPASSWORD
unset PGCLIENTENCODING

echo "Finished."
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."
