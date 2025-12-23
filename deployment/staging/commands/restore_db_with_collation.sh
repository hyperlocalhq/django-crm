#!/usr/bin/env bash

# Run as:
# ./restore_db_with_collation.sh [ path/to/postgres.backup[ .gz ] ]

export DJANGO_SETTINGS_MODULE=museumsportal.settings.staging
PROJECT_PATH=/var/webapps/museumsportal

cd ${PROJECT_PATH} || exit 1
# shellcheck disable=SC1091
source venv/bin/activate
cd ${PROJECT_PATH}/project/museumsportal || exit 1

DATABASE=$(echo "from django.conf import settings; print(settings.DATABASES['default']['NAME'])" | python manage.py shell)
USER=$(echo "from django.conf import settings; print(settings.DATABASES['default']['USER'])" | python manage.py shell)
PORT=$(echo "from django.conf import settings; print(settings.DATABASES['default']['PORT'])" | python manage.py shell)
[[ -z "${DATABASE}" ]] && { echo "DATABASE value is empty!"; exit 1; }
[[ -z "${USER}" ]] && { echo "USER value is empty!"; exit 1; }
[[ -z "${PORT}" ]] && { echo "PORT value is empty!"; exit 1; }
BACKUP_FILE=temp.backup
BACKUP_PATH=${PROJECT_PATH}/db_backups/${BACKUP_FILE}

dump_db () {
  echo "Creating database dump to ${BACKUP_PATH}"
  pg_dump --username="${USER}" --port="${PORT}" --format=p --file="${BACKUP_PATH}" "${DATABASE}" || { echo "Dumping failed."; exit 1; }
  echo "Done."
}

drop_db () {
  echo "Droping db ${DATABASE}";
  dropdb --username="${USER}" --port="${PORT}" "${DATABASE}" || { echo "Drop db failed."; exit 1; }
  echo "Done."
}

create_db () {
  echo "Creating db ${DATABASE} from db_template_with_extensions with collation de_DE.UTF-8";
  createdb --username="${USER}" --port="${PORT}" --encoding=UTF-8 --lc-collate=de_DE.UTF-8 --owner="${USER}" --template=db_template_with_extensions "${DATABASE}"
  echo "Done."
}

feed_db () {
  [[ -z "$1" ]] && { echo "Backup file is empty!"; exit 1; }
  echo "Feeding ${DATABASE} from dump $1";
  psql --username="${USER}" --port="${PORT}" --quiet "${DATABASE}" < "$1"
  echo "Done."
}

remove_db_dump () {
  echo "Removing ${BACKUP_PATH}"
  rm "${BACKUP_PATH}"
  echo "Done."
}

SUCCESS_MSG="Database ${DATABASE} has been recreated with collation de_DE.UTF-8."

# Check if a DB dump is given
if [[ $# -eq 0 ]]; then
  # No dump given. Create a dump.
  dump_db && drop_db && create_db && feed_db ${BACKUP_PATH}
  echo "${SUCCESS_MSG}"
else
  # Check if given file exists
  DB_DUMP_PATH=$1
  if [ ! -f "${DB_DUMP_PATH}" ]; then
      echo "File ${DB_DUMP_PATH} not found."
      exit 1;
  fi
  # Use the given file to feed the new DB
  DB_DUMP_DIRNAME=$(dirname "${DB_DUMP_PATH}")
  if file --mime-type "${DB_DUMP_PATH}" | grep -q gzip$; then
    # file is gzipped, unzip it
    gunzip < "${DB_DUMP_PATH}" > "${DB_DUMP_DIRNAME}/${BACKUP_FILE}"
    [ -s "${DB_DUMP_DIRNAME}/${BACKUP_FILE}" ] || exit 1;
    drop_db && create_db && feed_db "${DB_DUMP_DIRNAME}/${BACKUP_FILE}"
    echo "${SUCCESS_MSG}"
  else
    # file is already unzipped
    [ -s "${DB_DUMP_PATH}" ] || exit 1;
    drop_db && create_db && feed_db "${DB_DUMP_PATH}"
    echo "${SUCCESS_MSG}"
  fi
fi
