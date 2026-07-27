# home-network

Documentation for my home lab: NAS-hosted Docker services and Home Assistant.

## Architecture

```
UGREEN DXP4800 Pro (NAS) — UGOS Pro, storage + Docker
├── Caddy         — reverse proxy
├── ActualBudget  — personal finance
└── ...

Raspberry Pi — Home Assistant OS (HAOS)
├── Home Assistant
└── AdGuard Home  — local DNS server (add-on)
```

DNS for `*.home.bjbr.me` is handled by AdGuard Home. New devices/services should get an entry added there once their IP is fixed.

## Workflow

Docker services are defined in `docker/<service>/compose.yml`. To deploy or update a single service, pull the latest repo and run:

```sh
cd docker/<service> && docker compose up -d
```

To update everything at once, see [Updating](#updating).

## Setting Up AdGuard Home

AdGuard Home runs as a Home Assistant add-on on the Raspberry Pi, alongside Home Assistant itself — so DNS keeps working even if the NAS goes down.

**1. Install the add-on**

The AdGuard Home add-on isn't in the default Home Assistant add-on store — add the community add-ons repository first: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**, add `https://github.com/hassio-addons/repository`. Then search for **AdGuard Home** and install it.

**2. Complete initial setup**

Open the add-on's web UI (or `http://192.168.0.6:3000` directly) and follow the setup wizard. When asked which interface to listen on, select **All interfaces**. Set a username and password.

**3. Add DNS rewrites**

In the AdGuard UI go to **Filters → DNS rewrites** and add the following:

| Domain | Answer |
|--------|--------|
| `adguard.home.bjbr.me` | `192.168.0.6` |
| `*.home.bjbr.me` | `192.168.0.5` |

The wildcard `*.home.bjbr.me` catches all services on the NAS, reverse-proxied through Caddy. The specific `adguard.home.bjbr.me` entry takes priority over the wildcard. Anything outside `home.bjbr.me` (e.g. `www.bjbr.me`) resolves normally via public DNS.

**4. Point your Windows machine at AdGuard**

Open **Settings → Network & Internet → Advanced network settings → [your adapter] → DNS server** and set the preferred DNS to `192.168.0.6`.

To verify it's working:
```sh
nslookup actualbudget.home.bjbr.me
```

It should return `192.168.0.5`.

## NAS — UGREEN DXP4800 Pro

Runs **UGOS Pro** (UGREEN's NAS OS).

**Storage**
| Drive | Size | Role |
|-------|------|------|
| WD Red | 4TB | Main volume |

- Filesystem: **btrfs** (chosen over ext4 for checksumming/bit-rot detection and snapshot support)
- RAID: currently **Basic** (single disk, no redundancy). Planned migration path once a second drive is added: **Basic → RAID 1** (UGOS supports this in-place without data loss — back up first regardless).
- Old drives pulled from previous PCs are connected via a USB-to-SATA adapter to copy data off before repurposing — never plugged directly into an empty bay (UGOS would prompt to initialize/format them).

**Docker**
- Installed via App Center → **Container Manager** (native Docker + Docker Compose support, no manual install needed).
- Portainer also installed from App Center for a friendlier multi-container/compose management UI.
- Shared folders for container persistent data are created *before* deploying a container and mounted in — UGOS exposes shared folders under `/media/<sharename>` inside containers.

**Network access**
- **Windows (SMB)**: Control Panel → File Services → SMB enabled. Accessed via `\\<nas-ip>\<sharename>` in File Explorer, or mapped as a persistent network drive.
- **Bonjour/mDNS**: enabled in Control Panel so the NAS is reachable as `<nas-name>.local` without needing to remember the IP (Windows 10/11 resolves `.local` natively — no Bonjour install needed, but the Windows network profile must be set to **Private** or the firewall blocks mDNS).
- **Initial discovery**: `find.ugreen.com` or the UGREEN NAS mobile app, if the NAS's IP isn't already known.
- DHCP reservation set on the router: **192.168.0.5** (SMB paths and any Caddy reverse-proxy config depend on this staying fixed).

**Remote access**
- Skipped binding a UGREEN account / UGREENlink relay — remote access, if needed, will go through the existing self-hosted Caddy reverse proxy instead of UGREEN's cloud relay service.

## Home Assistant

Runs as **Home Assistant OS (HAOS)** on a dedicated **Raspberry Pi** — not on the NAS.

- IP / hostname: DHCP reservation set on the router: **192.168.0.6**
- Access: _TBD — currently accessed directly, not yet decided whether to put it behind the Caddy reverse proxy at a `home.bjbr.me` subdomain like the other services_

## Adding Services

1. Create `docker/<service>/compose.yml`
2. If the service needs persistent data, bind-mount it to `/volume1/docker-data/<service>/` — **not** a Docker named volume, and **not** anywhere under the repo's own directory. This repo is public and gets `git pull`ed in place; data living inside the working tree risks eventually being committed. `/volume1/docker-data` sits entirely outside it.
3. Run `docker compose up -d` from that directory

## Updating

To just pull the latest changes from git without touching any containers:

```sh
./pull.sh
```

To pull and redeploy every service in one shot:

```sh
./update.sh
```

Both use the `alpine/git` image to pull (so git doesn't need to be installed on the host) — no authentication needed since this repo is public. `update.sh` calls `pull.sh` first, then runs `docker compose pull && docker compose up -d` for each service directory, and prunes dangling images afterward.

`caddy` is always updated first — it creates the shared `caddy` Docker network that every other service joins, so it must exist before the rest come up.

## Network

| Device/Service | IP | Port | Domain |
|-----------------|--------------|------|--------|
| UGREEN NAS | 192.168.0.5 | — | — |
| ActualBudget | 192.168.0.5 | 5006 | `actualbudget.home.bjbr.me` |
| Home Assistant (Pi) | 192.168.0.6 | 8123 | — |
| AdGuard (on HA Pi) | 192.168.0.6 | 3000 | `adguard.home.bjbr.me` |
</content>
