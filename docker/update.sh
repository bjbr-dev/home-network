#!/bin/sh
set -e
cd "$(dirname "$0")/.."

docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/repo" -w /repo alpine/git pull

for dir in docker/*/; do
  service=$(basename "$dir")
  echo "==> Updating $service"
  (cd "$dir" && docker compose pull && docker compose up -d)
done

docker image prune -f
