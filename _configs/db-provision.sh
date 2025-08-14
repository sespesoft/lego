#!/bin/bash
set -e

create_database_if_not_exists() {
    local db_name=$1
    local owner=$2
    local password=$3
    echo "Configurando la base de datos '$db_name' para el usuario '$owner'..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        DO \$\$BEGIN
           IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$owner') THEN
              CREATE ROLE $owner LOGIN PASSWORD '$password';
           END IF;
        END\$\$;
EOSQL
    if ! psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"$db_name\" WITH OWNER = '$owner'"
    fi
}

create_database_if_not_exists "$APP_DB_NAME" "$APP_DB_USER" "$APP_DB_PASSWORD"
create_database_if_not_exists "$BI_DB_NAME" "$BI_DB_USER" "$BI_DB_PASSWORD"
create_database_if_not_exists "$GF_DB_NAME" "$GF_DB_USER" "$GF_DB_PASSWORD"
create_database_if_not_exists "$SS_DB_NAME" "$SS_DB_USER" "$SS_DB_PASSWORD"
