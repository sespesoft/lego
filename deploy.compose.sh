#!/bin/bash
set -eo pipefail
cd /home/deployer/lego
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

MAX_WAIT_SECONDS=300
CHECK_INTERVAL_SECONDS=10
SECONDS_WAITED=0
VAR_NAME_TO_UPDATE=$(echo "${ECR_REPOSITORY%%-*}" | tr 'a-z' 'A-Z')_IMAGE

if grep -q "^${VAR_NAME_TO_UPDATE}=" ".env"; then
  sed -i "s|^${VAR_NAME_TO_UPDATE}=.*|${VAR_NAME_TO_UPDATE}=${ECR_REGISTRY}\/${ECR_REPOSITORY}:${TAG}|" ".env"
else
  echo "${VAR_NAME_TO_UPDATE}=${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}" >> ".env"
fi

docker compose --profile infra --profile job up -d
while true; do
  running_jobs=$(docker ps --filter "label=service.role=job" --filter "status=running" --format "{{.Names}}")
  if [ -z "${running_jobs}" ]; then
    break
  fi
  if [ ${SECONDS_WAITED} -ge ${MAX_WAIT_SECONDS} ]; then
    echo "¡ERROR! Tiempo de espera máximo alcanzado (${MAX_WAIT_SECONDS} s)."
    echo "Los siguientes jobs no han terminado (pueden estar en un bucle de reinicio por fallo):"
    echo "${running_jobs}"
    for job in ${running_jobs}; do
      echo "--- Logs de ${job} ---"
      docker logs "${job}" --tail 50
    done
    exit 1
  fi
  sleep ${CHECK_INTERVAL_SECONDS}
  SECONDS_WAITED=$((SECONDS_WAITED + CHECK_INTERVAL_SECONDS))
done
docker compose --profile app up -d --remove-orphans
docker image prune -a -f
