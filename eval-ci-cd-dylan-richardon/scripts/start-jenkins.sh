#!/usr/bin/env bash
set -euo pipefail
IMAGE_NAME="quicknotes-jenkins"
CONTAINER_NAME="jenkins-quicknotes"
JENKINS_HOME="$(pwd)/jenkins_home"
mkdir -p "$JENKINS_HOME"
docker build -t "$IMAGE_NAME" -f ./jenkins/Dockerfile.jenkins .
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi
docker run -d \
  --name "$CONTAINER_NAME" \
  -p 8080:8080 \
  -p 50000:50000 \
  -v "$JENKINS_HOME:/var/jenkins_home" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  "$IMAGE_NAME"
echo "Jenkins lancé : http://localhost:8080"
echo "Mot de passe initial :"
docker exec -it "$CONTAINER_NAME" cat /var/jenkins_home/secrets/initialAdminPassword
