# Zero-downtime deployments with Podman (or Docker)

The motivation is to deploy an updated version of a container without service
interruption. We want to keep things lightweight and only use rootless Podman
(alternatively, Docker).

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
     docker.io/caddy:2-alpine caddy reverse-proxy --from :80 --to greet
   ```

   This Caddy reverse proxy forwards port 80 to the DNS name "greet".

1. **Start version A** of your service with

   ```bash
   podman run --detach --env HI_VERSION=A --name hi-0 --network test-net \
     --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   Most importantly, we give the container the network alias "greet".

   This container happens to use Caddy as well, but it can be anything that
   exposes port 80.

   Testing with `curl localhost:8080` should now return "Hi from _A_".

   To see the following update in action, you could keep a test loop running in
   a separate shell session with

   ```bash
   while true; do curl --fail --max-time 0.2 localhost:8080; sleep 0.01s; done
   ```

1. **Start version B** of your service with

   ```bash
   podman run --detach --env HI_VERSION=B --name hi-1 --network test-net \
     --network-alias greet --volume "${PWD}/hi.Caddyfile:/etc/caddy/Caddyfile" \
     docker.io/caddy:2-alpine
   ```

   At this point, both service versions are running at the same time with the
   same network alias.

1. **Stop version A** of your service with

   ```bash
   podman stop hi-0
   ```

   Testing with `curl localhost:8080` should now return "Hi from _B_". With
   that, the update is deployed.

You can clean up above experiments with

```bash
podman stop hi-1 reverse-proxy
podman rm hi-0 hi-1 reverse-proxy
podman network rm test-net
```

Run the whole demo automatically with the script `scripts/demo.sh`.

## Docker

Above also works with Docker, just replace `podman` by `docker` in the commands.

## See also

Like to automate this? See [Kerek](https://github.com/evolutics/kerek)!
