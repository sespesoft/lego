#!/bin/bash
set -eo pipefail
cd /home/deployer/lego

set -a
source .env
set +a

: "${ENV:?ENV no está definido}"

STACK_NAME="${APP_NAME:-sespesoft}-${ENV}"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

VAR_NAME_TO_UPDATE=$(echo "${ECR_REPOSITORY%%-*}" | tr 'a-z' 'A-Z')_IMAGE
IMAGE_REF="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

if grep -q "^${VAR_NAME_TO_UPDATE}=" ".env"; then
  sed -i "s|^${VAR_NAME_TO_UPDATE}=.*|${VAR_NAME_TO_UPDATE}=${IMAGE_REF}|" ".env"
else
  echo "${VAR_NAME_TO_UPDATE}=${IMAGE_REF}" >> ".env"
fi

echo "==> Stack objetivo: ${STACK_NAME} (ENV=${ENV})"

echo "==> Desplegando infraestructura y jobs..."
docker compose --profile infra --profile job config | \
  docker stack deploy --with-registry-auth -c - "${STACK_NAME}" --detach=false

echo "==> Desplegando aplicación..."
docker compose --profile app config | \
  docker stack deploy --with-registry-auth -c - "${STACK_NAME}" --detach=false

echo "==> Reconciliando stack completo y limpiando servicios obsoletos..."
docker compose --profile all config | \
  docker stack deploy --with-registry-auth --prune -c - "${STACK_NAME}"

echo "==> Despliegue completado en el stack '${STACK_NAME}'."
