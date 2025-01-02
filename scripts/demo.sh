#!/bin/bash

set -o errexit -o nounset -o pipefail

cd "$(git rev-parse --show-toplevel)"

declare -r engine="${1-podman}"
declare -r reverse_proxy="${2-caddy}"

"${engine}" network create test-net

case "${reverse_proxy}" in
  caddy)
    "${engine}" run --detach --name reverse-proxy --network test-net \
      --publish 127.0.0.1:8080:8181 \
      docker.io/caddy:2 caddy reverse-proxy --from :8181 --to greet:8282
    ;;
  haproxy)
    "${engine}" run --detach --name reverse-proxy --network test-net \
      --publish 127.0.0.1:8080:8181 \
      --volume ./haproxy:/usr/local/etc/haproxy:ro docker.io/haproxy:3.1
    ;;
  *)
    echo "Unknown reverse proxy: ${reverse_proxy}"
    exit 1
    ;;
esac

"${engine}" run --detach --name hi-0 --network test-net --network-alias greet \
  docker.io/hashicorp/http-echo:1.0 -listen=:8282 -text='Hi from A'

sleep 2s

while true; do
  curl --fail --max-time 0.2 --silent localhost:8080 || echo "Error $?"
  sleep 0.01s
done | tee test.log &

sleep 2s

"${engine}" run --detach --name hi-1 --network test-net --network-alias greet \
  docker.io/hashicorp/http-echo:1.0 -listen=:8282 -text='Hi from B'

sleep 2s

"${engine}" stop hi-0

sleep 2s

kill %%

"${engine}" rm --force hi-0 hi-1 reverse-proxy
"${engine}" network rm test-net

grep 'Hi from A' test.log
grep 'Hi from B' test.log
grep Error test.log && exit 1
:
