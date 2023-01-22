# Zero-downtime deployments with Podman (or Docker)

## Demo

1. Run the **reverse proxy** on a network with

   ```bash
   podman network create test-net

   podman run --detach --name reverse-proxy --network test-net \
     --publish 127.0.0.1:8080:80 \
     --volume "${PWD}/reverse-proxy.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   This Caddy reverse proxy forwards port 80 to the DNS name "greet" (see its
   [`Caddyfile`](reverse-proxy.Caddyfile) for details).

1. **Start version 0** of your service with

   ```bash
   podman run --detach --env HI_VERSION=0 --name hi-v0 --network test-net \
     --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   Most importantly, we give the container the network alias "greet".

   This container happens to use Caddy as well, but it can be anything that
   exposes port 80.

   Testing with `curl localhost:8080` should now return "Hi from _v0_". To see
   the following update in action, you could keep a test loop running in a
   separate shell session with

   ```bash
   while true; do curl --fail --max-time 0.2 localhost:8080; sleep 0.01s; done
   ```

1. **Start version 1** of your service with

   ```bash
   podman run --detach --env HI_VERSION=1 --name hi-v1 --network test-net \
     --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   At this point, both service versions are running at the same time with the
   same network alias.

1. **Stop version 0** of your service with

   ```bash
   podman stop hi-v0
   ```

   Testing with `curl localhost:8080` should now return "Hi from _v1_". With
   that, the update is deployed.

1. Optionally **clean up** above experiments with

   ```bash
   podman stop hi-v1 reverse-proxy
   podman rm hi-v0 hi-v1 reverse-proxy
   podman network rm test-net
   ```
