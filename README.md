# Zero-downtime deployments with Podman (or Docker)

The motivation is to deploy an updated version of a container without service
interruption. We want to keep things light and only use rootless Podman.

This works with Docker, too, just replace `podman` by `docker` in the commands
below.

## Overview

Say we want to replace a service container `hi-0` by `hi-1`. To keep the service
always available during such a deployment, a reverse proxy forwards access to
the service container(s) via their identical domain name `greet`:

```mermaid
flowchart TD
    localhost:8080 ---|:8181| proxy[Container reverse-proxy]
    proxy ---|greet:8282| hi0[Container hi-0]
    proxy ---|greet:8282| hi1[Container hi-1]
```

At any given time, at least one service container is available by making sure
their lifetimes overlap:

```
____________________________________
Container hi-0                      Stop
                        ____________________________________
                        Start                 Container hi-1

                        ^^^^^^^^^^^^
                        Overlap
```

## Demo

The following shows how to do such a deployment interactively.

1. Run the **reverse proxy** on a network with

   ```bash
   podman network create test-net

   podman run --detach --name reverse-proxy --network test-net \
     --publish 127.0.0.1:8080:8181 \
     docker.io/caddy:2 caddy reverse-proxy --from :8181 --to greet:8282
   ```

   This Caddy reverse proxy forwards port 8181 to the domain name `greet`,
   port 8282.

1. **Start version A** of your service with

   ```bash
   podman run --detach --name hi-0 --network test-net --network-alias greet \
     docker.io/hashicorp/http-echo:1.0 -listen=:8282 -text='Hi from A'
   ```

   This container responds with a greeting to requests on port 8282. Most
   importantly, we give it the network alias `greet`.

   Testing with `curl localhost:8080` should now return "Hi from _A_".

   To see the following update in action, you could keep a test loop running in
   a separate shell session with

   ```bash
   while true; do curl --fail --max-time 0.2 localhost:8080; sleep 0.01s; done
   ```

1. **Start version B** of your service with

   ```bash
   podman run --detach --name hi-1 --network test-net --network-alias greet \
     docker.io/hashicorp/http-echo:1.0 -listen=:8282 -text='Hi from B'
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
podman rm --force hi-0 hi-1 reverse-proxy
podman network rm test-net
```

Run the whole demo automatically with the script `scripts/demo.sh`.

## Docker Compose

Above can be automated in Docker Compose with
[Kerek (see example there)](https://github.com/evolutics/kerek).

## Tested reverse proxies

These reverse proxies have been tested:

- Caddy
- HAProxy

See the [demo code](scripts/demo.sh) for an example each.

## Known issues

If possible, use the very latest Podman version as earlier versions may not pass
above demo; Podman 5.2.3 for instance has shown intermittent DNS issues.
