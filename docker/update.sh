#!/bin/sh
set -e
cd "$(dirname "$0")/.."

docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/repo" -w /repo alpine/git pull

# caddy must come first — it creates the shared "caddy" network other services join
echo "==> Updating caddy"
(cd docker/caddy && docker compose pull && docker compose up -d)

for dir in docker/*/; do
  service=$(basename "$dir")
  [ "$service" = "caddy" ] && continue
  echo "==> Updating $service"
  (cd "$dir" && docker compose pull && docker compose up -d)
done

docker image prune -f
