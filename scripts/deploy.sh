#!/bin/sh
# Déploie PayMyBuddy via SSH + docker compose
# Variables: SSH_HOST, IMAGE_NAME, DOCKERHUB_USR, DOCKERHUB_PSW, DEPLOY_USER (défaut ubuntu)

set -eu

DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
REMOTE_DIR="paymybuddy-deploy"

if [ -z "${SSH_HOST:-}" ] || [ -z "${IMAGE_NAME:-}" ]; then
  echo "ERROR: SSH_HOST et IMAGE_NAME sont obligatoires"
  exit 1
fi

echo "==> Déploiement de ${IMAGE_NAME} sur ${DEPLOY_USER}@${SSH_HOST}"

ssh -o StrictHostKeyChecking=yes "${DEPLOY_USER}@${SSH_HOST}" "mkdir -p ~/${REMOTE_DIR}"
scp deploy/docker-compose.yml "${DEPLOY_USER}@${SSH_HOST}:~/${REMOTE_DIR}/docker-compose.yml"

ssh -o StrictHostKeyChecking=yes "${DEPLOY_USER}@${SSH_HOST}" \
  "cd ~/${REMOTE_DIR} && \
   echo '${DOCKERHUB_PSW}' | docker login -u '${DOCKERHUB_USR}' --password-stdin && \
   export IMAGE_NAME='${IMAGE_NAME}' MYSQL_ROOT_PASSWORD='${MYSQL_ROOT_PASSWORD:-password}' MYSQL_USER='${MYSQL_USER:-root}' && \
   docker compose pull && \
   docker compose up -d && \
   docker compose ps"

echo "==> Déploiement terminé: http://${SSH_HOST}:8080"
