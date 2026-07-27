#!/bin/sh
set -e
cd "$(dirname "$0")"

docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/repo" -w /repo alpine/git pull
