#!/bin/bash

export PGPASSWORD=${DB_PASSWORD:-"postgres"}

echo "Iniciando script de configuración de Token para Grafana..."

until psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1 FROM \"user\" LIMIT 1;" > /dev/null 2>&1; do
  echo "Esperando a que Grafana cree las tablas (migraciones)..."
  sleep 3
done

echo "Tablas detectadas. Procediendo con la inserción de datos..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO public.user (
    id, version, login, email, name, password, salt, rands, company,
    org_id, is_admin, email_verified, theme, created, updated, help_flags1,
    last_seen_at, is_disabled, is_service_account, uid, is_provisioned
) VALUES (
    2, 0, 'sa-1-test-connection', 'sa-1-test-connection', 'test-connection',
    '', 'VvyCCli1oj', 'WWbLFXNteR', '', 1, false, false, '', '2026-01-02 16:31:11',
    '2026-01-02 16:31:11', 0, '2026-01-10 15:49:31', false, true, 'df8sp328clcsga', false
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_key (
    id, org_id, name, key, role, created, updated, expires,
    service_account_id, last_used_at, is_revoked
) VALUES (
    1, 1, 'sa-1-test-connection-aa8a5a3b-1e77-4da9-a41e-567cda16a30b',
    '513f0c216d3f75f6cebf63caa31f02cb6a30e736aeb90a2bc5d41ab71a182ff35a1c6364014edb1c59abf280da02d7126eeb',
    'Viewer', '2026-02-18 19:56:02', '2026-02-18 19:56:02', null, 2, '2026-02-19 16:58:44', false
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.org_user (
    id, org_id, user_id, role, created, updated
) VALUES (
    2, 1, 2, 'Viewer', '2026-02-19 16:45:36', '2026-02-19 16:45:37'
) ON CONFLICT (id) DO NOTHING;
EOF

echo "Configuración finalizada exitosamente."
