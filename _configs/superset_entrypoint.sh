#!/bin/bash
set -e

superset db upgrade
superset fab create-admin \
            --username "${ADMIN_USERNAME}" \
            --firstname "${ADMIN_FIRSTNAME}" \
            --lastname "${ADMIN_LASTNAME}" \
            --email "${ADMIN_EMAIL}" \
            --password "${ADMIN_PASSWORD}"
superset init
exec /usr/bin/run-server.sh
