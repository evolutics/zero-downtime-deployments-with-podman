# Zero-downtime deployments with Podman (or Docker)

The motivation is to deploy an updated version of a container without service
interruption. We want to keep it lightweight and only use (rootless) Podman or
Docker.

## Overview

Say we want to replace a service container `hi-0` by `hi-1`. To keep the service
always available during such a deployment, a reverse proxy forwards access to
the service container(s) via their identical network alias "greet":

```
                                   ┃ localhost:8080
╭┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┃┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄╮
┆ Network test-net                 ┃                                  ┆
┆                                  ┃ :80                              ┆
┆         ╭────────────────────────┸────────────────────────╮         ┆
┆         │ Container reverse-proxy                         │         ┆
┆         ╰─────────┰─────────────────────────────┰─────────╯         ┆
┆                   ┃                             ┃                   ┆
┆                   ┃ greet:80                    ┃ greet:80          ┆
┆         ╭─────────┸─────────╮         ╭─────────┸─────────╮         ┆
┆         │ Container hi-0    │         │ Container hi-1    │         ┆
┆         ╰───────────────────╯         ╰───────────────────╯         ┆
┆                                                                     ┆
╰┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄╯
```

At any given time, at least one service container is available by making sure
their lifetimes overlap:

```
hi-0 ready                               hi-0 stopping
❰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┽┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┨

           hi-1 starting       hi-1 ready
          ┠┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┾━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━❱
```

## Demo

The following shows how to do such a deployment interactively.

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
   podman run --detach --env HI_VERSION=0 --name hi-0 --network test-net \
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
   podman run --detach --env HI_VERSION=1 --name hi-1 --network test-net \
     --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   At this point, both service versions are running at the same time with the
   same network alias.

1. **Stop version 0** of your service with

   ```bash
   podman stop hi-0
   ```

   Testing with `curl localhost:8080` should now return "Hi from _v1_". With
   that, the update is deployed.

You can clean up above experiments with

```bash
podman stop hi-1 reverse-proxy
podman rm hi-0 hi-1 reverse-proxy
podman network rm test-net
```

## Docker

Above also works with Docker, just replace `podman` by `docker` in the commands.
