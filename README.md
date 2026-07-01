# home-network

Documentation for the non-Proxmox parts of my home network: the NAS and Home Assistant. Proxmox/Docker host setup lives in the separate [`proxmox`](https://github.com/bjbr-dev/proxmox) repo.

## Architecture

```
Home network
├── UGREEN DXP4800 Pro (NAS)     — UGOS Pro, storage + Docker containers
└── Raspberry Pi                 — Home Assistant OS (HAOS)
```

DNS for `*.home.bjbr.me` is handled by AdGuard Home (see the `proxmox` repo) — new devices/services here should get an entry added there once their IP is fixed.

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
- Skipped binding a UGREEN account / UGREENlink relay — remote access, if needed, will go through the existing self-hosted Caddy reverse proxy (`proxmox` repo) instead of UGREEN's cloud relay service.

## Home Assistant

Runs as **Home Assistant OS (HAOS)** on a dedicated **Raspberry Pi** — not on the NAS or the Proxmox Docker host.

- IP / hostname: DHCP reservation set on the router: **192.168.0.6**
- Access: _TBD — currently accessed directly, not yet decided whether to put it behind the Caddy reverse proxy at a `home.bjbr.me` subdomain like the other services_

## Network

| Device/Service | IP | Port | Domain |
|----------------|-----|------|--------|
| UGREEN NAS | 192.168.0.5 | — | — |
| Home Assistant (Pi) | 192.168.0.6 | 8123 | — |

See the `proxmox` repo's network table for Proxmox host, AdGuard, and Docker-hosted services.
