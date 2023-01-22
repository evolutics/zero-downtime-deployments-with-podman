#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

podman network create test-net

podman run --detach --name reverse-proxy --network test-net \
  --publish 127.0.0.1:8080:80 \
  --volume "${PWD}/reverse-proxy.Caddyfile:/etc/caddy/Caddyfile" \
  docker.io/caddy:2-alpine

podman run --detach --env HI_VERSION=0 --name hi-0 --network test-net \
  --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
  docker.io/caddy:2-alpine

sleep 2s

while true; do
  curl --fail --max-time 0.2 --silent localhost:8080 || echo "Error $?"
  sleep 0.01s
done | tee test.log &

podman run --detach --env HI_VERSION=1 --name hi-1 --network test-net \
  --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
  docker.io/caddy:2-alpine

sleep 2s

podman stop hi-0

sleep 2s

kill %%

grep 'Hi from v0' test.log
grep 'Hi from v1' test.log
grep Error test.log && exit 1

podman stop hi-1 reverse-proxy
podman rm hi-0 hi-1 reverse-proxy
podman network rm test-net
