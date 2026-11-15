# Deployment

How this fork gets built and shipped. Two paths exist: the **NAS** (self-hosted
production, what actually runs) and the older script set in `script/`.

| Doc | Purpose |
| --- | --- |
| [`nas/README.md`](nas/README.md) | `script/deploy-nas.sh` reference: stack layout, build/transfer/deploy flow, 2026-11 changelog, gotchas |
| [`deployment-guide.md`](deployment-guide.md) | The script-per-change deployment guide (Docker rebuild vs hot-patch), decision flow |
| [`docker-build-troubleshooting.md`](docker-build-troubleshooting.md) | Build failures, cache problems, platform/QEMU issues |

## Current production

| | |
| --- | --- |
| Host | `taborator.rhaps.net:24` (Synology DS220+) |
| URL | <https://msp.rhaps.net> |
| Stack | `docker-compose.nas.yml` — `postgres`, `redis`, `web` (Rails/Puma), `worker` (Sidekiq) |
| Images | `chatwoot:nas-web`, `chatwoot:nas-worker` (cross-built on the Mac for `linux/amd64`) |

Deployment scripts must be run by a human — agent sessions cannot SSH to the NAS.

## Related

- Deployment scripts: `script/deploy-nas.sh`, `script/deploy-production-docker.sh`,
  `script/deploy-apple-pay-certs.sh`
- Compose file: `docker-compose.nas.yml`
- Build: `Dockerfile.production` (NAS/Cloud Run), `Dockerfile.production.lightweight`
