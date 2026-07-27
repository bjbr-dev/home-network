#!/bin/sh
set -e
cd "$(dirname "$0")"

./pull.sh

# caddy must come first — it creates the shared "caddy" network other services join
echo "==> Updating caddy"
(cd docker/caddy && docker compose pull && docker compose up -d --build)

for dir in docker/*/; do
  service=$(basename "$dir")
  [ "$service" = "caddy" ] && continue
  echo "==> Updating $service"
  (cd "$dir" && docker compose pull && docker compose up -d --build)
done

docker image prune -f
