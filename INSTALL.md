# Fresh NAS Setup

Steps to go from a brand-new UGREEN NAS to running services from this repo, with no manual git or Docker install needed on the host.

## 1. Enable SSH

Control Panel → Terminal & SNMP → enable SSH service.

## 2. Install Docker

App Center → install **Container Manager** (bundles Docker Engine + Docker Compose — no manual install needed).

## 3. SSH in and prepare a folder for repos

```sh
ssh <user>@<nas-ip>
sudo mkdir -p /volume1/docker
sudo chown "$USER":"$(id -gn)" /volume1/docker
```

`$USER:$USER` doesn't work here — UGOS doesn't create a same-named group per user like standard Linux. `id -gn` looks up your actual primary group instead.

## 4. Allow your user to run Docker without sudo

```sh
sudo usermod -aG docker "$USER"
```

Log out and SSH back in for the new group membership to take effect (`newgrp docker` only affects the current shell, not future sessions). Verify with:

```sh
docker ps
```

If this still fails with a permission error after re-login, UGOS's Container Manager may not use the standard `docker` group for permissions — fall back to prefixing docker commands with `sudo`.

## 5. Clone this repo — no git install required

```sh
docker run --rm -u "$(id -u):$(id -g)" \
  -v /volume1/docker:/data -w /data \
  alpine/git clone https://github.com/bjbr-dev/home-network.git
```

This repo is public, so no authentication is needed.

## 6. Deploy services

Before starting Caddy, create `docker/caddy/cloudflare.env` with a Cloudflare API token scoped to the `bjbr.me` zone — see [Setting Up Caddy](README.md#setting-up-caddy) in the README. Then deploy Caddy first, since it owns the shared Docker network the other services join (`--build` is required the first time, to build Caddy's custom image with the Cloudflare DNS plugin):

```sh
cd /volume1/docker/home-network
cd docker/caddy && docker compose up -d --build
cd ../actualbudget && docker compose up -d
```

## 7. Point DNS at the NAS

Add/update the `*.home.bjbr.me` DNS rewrite in AdGuard Home to the NAS's static IP — see the [Setting Up AdGuard Home](README.md#setting-up-adguard-home) section in the README.

## Updating later

From the repo root:

```sh
./update.sh
```

Pulls the latest repo changes (via the same dockerized git, no host install) and redeploys every service. For just a git pull without touching containers, use `./pull.sh` instead. See [Updating](README.md#updating) in the README for details.
