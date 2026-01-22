#!/usr/bin/env bash


set -euo pipefail

IMAGE="mohajernoei/websecurity"
NODE_PORT="${1:-3000}"
WG_PORT="${2:-8080}"
WW_PORT="${3:-9090}"
#docker pull "${IMAGE}"
docker run --platform=linux/amd64 --rm -it \
  -p "${NODE_PORT}:3000" \
  -p "${WG_PORT}:8080" \
  -p "${WW_PORT}:9090" \
  --volume .:/app/ \
  "${IMAGE}" 

