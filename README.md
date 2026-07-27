# home-network

Documentation for my home lab: Proxmox host, Docker services, NAS, and Home Assistant.

## Architecture

```
Proxmox (bare metal)
├── LXC: adguard      — local DNS server
└── VM: docker-1      — Docker host
    ├── Caddy         — reverse proxy
    ├── ActualBudget  — personal finance
    ├── Portainer     — container management UI
    └── ...

UGREEN DXP4800 Pro (NAS) — UGOS Pro, storage
Raspberry Pi             — Home Assistant OS (HAOS)
```

DNS for `*.home.bjbr.me` is handled by AdGuard Home. New devices/services should get an entry added there once their IP is fixed.

## Workflow

Docker services are defined in `docker/<service>/compose.yml`. To deploy or update a single service, pull the latest repo and run:

```sh
cd docker/<service> && docker compose up -d
```

To update everything at once, see [Updating All Services](#updating-all-services).

## Initial Proxmox Setup

Download and install Proxmox onto bare metal: https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso

Once logged in, run the post-install script:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

## Setting Up the Docker Host VM

Create a Debian VM in Proxmox from https://www.debian.org/distrib/netinst with the following specs, then follow these steps.

| Resource | Value |
|----------|-------|
| Cores    | 8     |
| RAM      | 16384 MiB (16GB) |
| Disk     | 120 GB |

Enable the QEMU Guest Agent in Proxmox under **Options → QEMU Guest Agent** before starting the VM.

**0. Reserve a static IP for the VM**

Find the VM's MAC address in Proxmox under **Hardware → Network Device** and create a DHCP reservation in your router so the VM always gets the same IP (e.g. `192.168.0.10`).

**1. Set up sudo and SSH** (run as root: `su -`)
```sh
apt-get install -y sudo openssh-server
usermod -aG sudo james
exit
```

Then log out and SSH in from your machine — you can paste commands freely from here on:
```sh
ssh james@<vm-ip>
```

**2. Install dependencies**
```sh
sudo apt-get update && sudo apt-get install -y git curl ca-certificates qemu-guest-agent
```

**3. Install Docker**
```sh
curl -fsSL https://get.docker.com | sudo sh
```

**4. Allow your user to run Docker without sudo**
```sh
sudo usermod -aG docker $USER
newgrp docker
```

**5. Install the GitHub CLI**
```sh
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt-get update && sudo apt-get install -y gh
```

**6. Authenticate with GitHub**
```sh
gh auth login
```

Follow the prompts — choose GitHub.com, HTTPS, and authenticate via browser or token.

**7. Clone this repo**
```sh
gh repo clone bjbr-dev/home-network ~/home-network
```

## Setting Up AdGuard Home

AdGuard Home runs as its own LXC container on Proxmox, separate from the Docker host. This way DNS keeps working even if the Docker VM goes down.

**1. Create the LXC**

Run this from the Proxmox shell (**node → Shell**):
```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/adguard.sh)"
```

Follow the prompts. Give it a static IP (e.g. `192.168.0.3/24`) and gateway of `192.168.0.1` when asked.

**2. Complete initial setup**

Open `http://192.168.0.3:3000` in your browser and follow the setup wizard. When asked which interface to listen on, select **All interfaces**. Set a username and password.

After setup the web UI moves to `http://192.168.0.3:3000` permanently.

**3. Add DNS rewrites**

In the AdGuard UI go to **Filters → DNS rewrites** and add the following:

| Domain | Answer |
|--------|--------|
| `proxmox.home.bjbr.me` | `192.168.0.2` |
| `adguard.home.bjbr.me` | `192.168.0.3` |
| `*.home.bjbr.me` | `192.168.0.10` |

The wildcard `*.home.bjbr.me` catches all services on the Docker host. Specific entries like Proxmox and AdGuard take priority over the wildcard. Anything outside `home.bjbr.me` (e.g. `www.bjbr.me`) resolves normally via public DNS.

**4. Point your Windows machine at AdGuard**

Open **Settings → Network & Internet → Advanced network settings → [your adapter] → DNS server** and set the preferred DNS to `192.168.0.3`.

To verify it's working:
```sh
nslookup actualbudget.home.bjbr.me
```

It should return `192.168.0.10`.

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

Runs as **Home Assistant OS (HAOS)** on a dedicated **Raspberry Pi** — not on the NAS or the Proxmox Docker host.

- IP / hostname: DHCP reservation set on the router: **192.168.0.6**
- Access: _TBD — currently accessed directly, not yet decided whether to put it behind the Caddy reverse proxy at a `home.bjbr.me` subdomain like the other services_

## Adding Services

1. Create `docker/<service>/compose.yml`
2. Run `docker compose up -d` from that directory

## Updating All Services

Pull the latest compose files and refresh every service's image in one shot:

```sh
./docker/update.sh
```

This pulls repo changes via the `alpine/git` image (so git doesn't need to be installed on the host), then runs `docker compose pull && docker compose up -d` for each service directory, and prunes dangling images afterward. No authentication needed — this repo is public.

## Network

| Device/Service | IP | Port | Domain |
|-----------------|--------------|------|--------|
| Proxmox | 192.168.0.2 | 8006 | `proxmox.home.bjbr.me` |
| AdGuard | 192.168.0.3 | 3000 | `adguard.home.bjbr.me` |
| docker-1 | 192.168.0.10 | — | — |
| ActualBudget | 192.168.0.10 | 5006 | `actualbudget.home.bjbr.me` |
| UGREEN NAS | 192.168.0.5 | — | — |
| Home Assistant (Pi) | 192.168.0.6 | 8123 | — |
</content>
