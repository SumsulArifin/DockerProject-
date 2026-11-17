#!/usr/bin/env bash
# Runs on the target EC2 instance (via SSM RunCommand) to deploy a new image tag,
# smoke-test it against /health, and roll back automatically on failure.
#
# Required environment: IMAGE (full image ref including new tag), CONTAINER_NAME, APP_PORT.
set -euo pipefail

IMAGE="${IMAGE:?IMAGE env var is required}"
CONTAINER_NAME="${CONTAINER_NAME:-devops-task-app}"
APP_PORT="${APP_PORT:-8080}"
STATE_FILE="/opt/app/current_image"

mkdir -p /opt/app
previous_image=""
if [ -f "${STATE_FILE}" ]; then
  previous_image="$(cat "${STATE_FILE}")"
fi

echo "Deploying image: ${IMAGE}"
docker pull "${IMAGE}"

docker rm -f "${CONTAINER_NAME}_new" >/dev/null 2>&1 || true
docker run -d \
  --name "${CONTAINER_NAME}_new" \
  -p 127.0.0.1:8081:"${APP_PORT}" \
  --restart unless-stopped \
  --log-driver=awslogs \
  --log-opt awslogs-group=/devops-task/app \
  --log-opt awslogs-create-group=true \
  -e PORT="${APP_PORT}" \
  -e APP_ENV=production \
  "${IMAGE}"

echo "Smoke testing new container on :8081/health ..."
ok=false
for _ in $(seq 1 10); do
  if curl -fsS "http://127.0.0.1:8081/health" >/dev/null 2>&1; then
    ok=true
    break
  fi
  sleep 2
done

if [ "${ok}" != "true" ]; then
  echo "Smoke test FAILED for ${IMAGE}. Rolling back." >&2
  docker rm -f "${CONTAINER_NAME}_new" >/dev/null 2>&1 || true
  if [ -n "${previous_image}" ]; then
    echo "Previous image remains running: ${previous_image}"
  fi
  exit 1
fi

echo "Smoke test passed. Promoting new container to live traffic."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm -f "${CONTAINER_NAME}_new" >/dev/null 2>&1 || true
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${APP_PORT}:${APP_PORT}" \
  --restart unless-stopped \
  --log-driver=awslogs \
  --log-opt awslogs-group=/devops-task/app \
  --log-opt awslogs-create-group=true \
  -e PORT="${APP_PORT}" \
  -e APP_ENV=production \
  "${IMAGE}"

echo "${IMAGE}" > "${STATE_FILE}"
echo "Deploy complete: ${IMAGE}"
