#!/bin/bash

set -e

INIT_FLAG="/app/superset_home/.initialized"

if [ ! -f "$INIT_FLAG" ]; then
  echo ">> First time running. Initializing Superset..."
  echo ">> Upgrading Superset database..."
  superset db upgrade
  echo ">> Creating admin user..."
  superset fab create-admin \
              --username ${ADMIN_USERNAME} \
              --firstname ${ADMIN_FIRSTNAME} \
              --lastname ${ADMIN_LASTNAME} \
              --email ${ADMIN_EMAIL} \
              --password ${ADMIN_PASSWORD}
  echo ">> Initializing Superset..."
  superset init
  echo ">> Initialization complete. Creating flag file."
  touch "$INIT_FLAG"
else
  echo ">> Initialization already done. Skipping."
  superset db upgrade
fi
echo ">> Starting Superset web server..."
exec /usr/bin/run-server.sh
