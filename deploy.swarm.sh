#!/bin/bash
set -aeo pipefail
source .env
set +a

: "${ENV:?ENV no está definido}"

STACK_NAME=$(echo "${COMPOSE_PROJECT_NAME:-${PWD##*/}}" | tr 'A-Z' 'a-z')
REQUIRED_LABELS=("app" "edge")
MANAGER_NODE=$(docker node ls --filter "role=manager" --format "{{.Hostname}}" | head -n1)
NODE_COUNT=$(docker node ls -q | wc -l)

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

VAR_NAME_TO_UPDATE=$(echo "${ECR_REPOSITORY%%-*}" | tr 'a-z' 'A-Z')_IMAGE
IMAGE_REF="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

if grep -q "^${VAR_NAME_TO_UPDATE}=" ".env"; then
  sed -i "s|^${VAR_NAME_TO_UPDATE}=.*|${VAR_NAME_TO_UPDATE}=${IMAGE_REF}|" ".env"
else
  echo "${VAR_NAME_TO_UPDATE}=${IMAGE_REF}" >> ".env"
fi

for label in "${REQUIRED_LABELS[@]}"; do
  match=$(docker node ls -q | xargs docker node inspect --format "{{index .Spec.Labels \"$label\"}}" | grep -c "true" || true)
  if [ "$match" -eq 0 ]; then
    if [ "$NODE_COUNT" -eq 1 ]; then
      echo "⚠️  Clúster de un solo nodo sin ${label}=true. Aplicando fallback al manager (${MANAGER_NODE})."
      docker node update --label-add "${label}=true" "${MANAGER_NODE}"
    else
      echo "❌ Clúster con ${NODE_COUNT} nodos y ninguno tiene ${label}=true. Abortando — asigna el label manualmente antes de desplegar."
      exit 1
    fi
  fi
done

docker swarm update --task-history-limit 1

docker compose -f docker-compose.yml -f docker-compose.cluster.yml --profile infra --profile job config | \
  docker stack deploy --with-registry-auth -c - "${STACK_NAME}" --detach=false

docker compose -f docker-compose.yml -f docker-compose.cluster.yml --profile app config | \
  docker stack deploy --with-registry-auth -c - "${STACK_NAME}" --detach=false

docker compose -f docker-compose.yml -f docker-compose.cluster.yml --profile all config | \
  docker stack deploy --with-registry-auth -c - --prune "${STACK_NAME}"
