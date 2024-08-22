#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r engine="${1-podman}"

"${engine}" network create test-net

"${engine}" run --detach --name reverse-proxy --network test-net \
  --publish 127.0.0.1:8080:80 \
  docker.io/caddy:2-alpine caddy reverse-proxy --from :80 --to greet

"${engine}" run --detach --name hi-0 --network test-net --network-alias greet \
  docker.io/caddy:2-alpine caddy respond --listen :80 $'Hi from A\n'

sleep 2s

while true; do
  curl --fail --max-time 0.2 --silent localhost:8080 || echo "Error $?"
  sleep 0.01s
done | tee test.log &

sleep 2s

"${engine}" run --detach --name hi-1 --network test-net --network-alias greet \
  docker.io/caddy:2-alpine caddy respond --listen :80 $'Hi from B\n'

sleep 2s

"${engine}" stop hi-0

sleep 2s

kill %%

grep 'Hi from A' test.log
grep 'Hi from B' test.log
grep Error test.log && exit 1

"${engine}" stop hi-1 reverse-proxy
"${engine}" rm hi-0 hi-1 reverse-proxy
"${engine}" network rm test-net
