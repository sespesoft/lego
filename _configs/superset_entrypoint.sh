#!/bin/bash
set -e

pip install psycopg2-binary --target /app/superset_home --no-cache-dir
export PYTHONPATH="/app/superset:/app/superset_home:/app/superset:/app/superset_home"
python3 -c "import psycopg2; print('EXITO: Psycopg2 cargado desde:', psycopg2.__file__)"

superset db upgrade
superset fab create-admin \
            --username "${ADMIN_USERNAME}" \
            --firstname "${ADMIN_FIRSTNAME}" \
            --lastname "${ADMIN_LASTNAME}" \
            --email "${ADMIN_EMAIL}" \
            --password "${ADMIN_PASSWORD}"
superset init
exec /usr/bin/run-server.sh
