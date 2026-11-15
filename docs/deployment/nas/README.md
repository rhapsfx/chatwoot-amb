# NAS Deployment — `script/deploy-nas.sh`

Reference notes for the Chatwoot stack that runs on the Synology NAS. Written to
answer "why does the script do this?" months later, and to record what changed
and how it was verified.

> Deployment scripts must be run manually by a human (`./script/deploy-nas.sh`);
> agent sessions cannot SSH to the NAS.

## Stack at a glance

| Piece | Value |
| --- | --- |
| Host / port | `taborator.rhaps.net:24` (Synology DS220+, `linux/amd64`) |
| SSH user | `mdu` (`--nas-user` / `$NAS_USER`) |
| Data dir on NAS | `/volume1/docker/chatwoot` |
| Public URL | <https://msp.rhaps.net> (Cloudflare tunnel, managed outside this stack) |
| Compose file | `docker-compose.nas.yml` |
| Services | `postgres` (`postgres:15-alpine`), `redis` (`redis:7-alpine`), `web` (Rails/Puma :8080), `worker` (Sidekiq) |
| Images | `chatwoot:nas-web`, `chatwoot:nas-worker` (same image, two tags) |

TLS/HTTP2 is terminated by **cloudflared** on the edge; cloudflared is attached
to the external network `cloudflare_rhaps_prod_net` and forwards plain HTTP/1.1
to `http://web:8080`. **No Node.js process runs in this stack** — see the
security note below.

## Deploy flow

1. **Pre-flight** — local `.env.production` + compose file exist, buildx builder
   supports `linux/amd64`, SSH works, NAS `docker` (and `docker compose`) located.
2. **Build** — `docker buildx build --platform linux/amd64 --load`, run on the
   Mac (ARM64 → AMD64 via QEMU). First build 30–90 min, cached rebuilds 2–5 min.
3. **Transfer** — `docker save | gzip -1 | ssh "<docker> load"` (~4–5 GB).
4. **Sync config** — atomic push of `.env.production`, `docker-compose.nas.yml`,
   and `certs/apple_pay/`.
5. **Remote deploy** — create bind-mount dirs + shared Docker network, start the
   stack, wait for readiness, print container status.

## Change log

### 2026-11-15 — Deploy script hardening + Node.js security update

#### A. `script/deploy-nas.sh` — correctness fixes

| # | Change | Before → After |
| --- | --- | --- |
| 1 | Readiness gating | Manual poll loop fell through after 12 attempts and started `web`/`worker` on an unready DB, then reported success. Now uses `docker compose up -d --wait` when the NAS compose supports it (probed via `compose up --help`), otherwise polls and **exits 1** with `postgres/redis not healthy after 60s`. |
| 2 | `--skip-build` guard | `docker save` failed with an opaque "reference does not exist". Now verifies **both** tags exist locally and dies with a clear message. |
| 3 | `--skip-transfer` semantics | Still ran the config sync + remote `up -d`, restarting the stack on the **old** NAS image while printing "deploy complete". Now exits right after the build: no transfer, no sync, no container changes. |
| 4 | Build stamp | Stamped `git HEAD`, but `docker build .` builds the **working tree** — local edits with an unchanged HEAD silently shipped a stale image. Now stamps a fingerprint of `HEAD` + `Dockerfile.production`/`.dockerignore` blobs + `git status --porcelain`. |
| 5 | credsStore fallback ordering | The first docker call (`buildx inspect`) ran **before** the temp-config workaround, so it could still trigger the macOS keychain prompt. Fallback now runs first and the probe goes through `docker_cmd`. |
| 6 | Config uploads | `ssh "cat > file"` truncated the live file if the connection dropped. Now uploads `<dest>.tmp`, chmods, then `mv -f` (atomic). |
| 7 | Secret permissions | `.env.production` is now mode `600`; a chmod failure on certs is no longer masked by `\|\| true`. Apple Pay certs deliberately stay `644` — see gotcha below. |
| 8 | Compose detection | Hardcoded `$NAS_DOCKER compose` fails on DSM builds that only ship legacy `docker-compose`. Now detects plugin vs binary once, dies if neither exists, and reuses the result everywhere (including the printed helper commands). |

Verification (no NAS access needed): the script was exercised end-to-end with
fake `ssh` (executes the remote command locally) and fake `docker` (marker-file
driven) binaries, covering: `--wait` path, polling path, never-healthy failure
(exit 1, `web`/`worker` not started), `--skip-build` with/without local images,
`--skip-transfer` no-op, clean-tree skip vs dirty-tree rebuild, atomic write
leaving no `.tmp`, and `600` on the pushed env file.

#### B. Node.js security update (advisories of 2026-11-11)

Node was pinned at **24.22.1** (`.nvmrc`) and the production image installed a
floating **22.x** via `deb.nodesource.com/setup_22.x` — both inside the affected
ranges of the 22.23.5 / 24.22.3 / 26.13.1 security releases.

Applicability to this deployment: **not exploitable**. The NAS stack runs no
Node process (Puma serves HTTP/1.1, cloudflared terminates TLS), so the
server-side flaws below have no attack surface. Node here is build-time asset
compilation plus dev tooling only. The bump is hygiene, not incident response.

| CVE | Needs | Applies here? |
| --- | --- | --- |
| CVE-2026-123863 (HTTP/2 crash) | Node `http2` server, 24.x/26.x | No |
| CVE-2026-123866 (HTTP/2 cross-connection leak) | Node `http2` server | No |
| CVE-2026-123864 (HTTPS heap copy / TLS key leak) | Node `https` server using `flushHeaders()` + body echo | No (dev scraper is Express on `node:http`, explicitly unaffected) |
| CVE-2026-126051 (TLS 1.2 renegotiation / SNI client-cert bypass) | Node TLS server with `SNICallback`/`addContext`/OCSP/session hooks | No |

Relevant in a build/dev context only: CVE-2026-123877 (`https.Agent` session
policy reuse) and CVE-2026-123871 (proxy credentials in error messages, i.e. in
build logs).

Pins updated to **24.22.3**:

| File | Note |
| --- | --- |
| `.nvmrc` | drives all CI (`node-version-file: .nvmrc`) and local dev |
| `docker/Dockerfile` | `node:24.22.3-alpine` base + two `NODE_VERSION` ARGs |
| `.devcontainer/docker-compose.yml`, `.devcontainer/docker-compose.base.yml` | `NODE_VERSION` |
| `.circleci/config.yml` | 3× `node-version` |
| `deployment/setup_20.04.sh` | `minimum_node_version` |
| `Dockerfile.production` | replaced floating `setup_22.x` (which contradicted `engines.node: 24.x`) with a pinned official tarball install |
| `Dockerfile.production.lightweight` | same pinned block, replacing **EOL Node 20** (`setup_20.x`), which receives no security fixes at all |

The pinned install is arch-aware (`TARGETARCH`: `amd64→x64`, `arm64→arm64`,
fallback `dpkg --print-architecture`) and asserts `node --version` during the
build. Verified by building the exact `RUN` block and running it for both
`linux/amd64` (v24.22.3 x64, the NAS target) and native arm64; both production
Dockerfiles pass `docker buildx build --check`; `node:24.22.3-alpine` resolved on
Docker Hub.

## Operational notes and gotchas

- **Build stamp format changed** in the 2026-11-15 update (bare SHA → tree
  fingerprint), so the first run afterwards rebuilds once even on an unchanged
  tree. Any dirty file in the repo — including unrelated docs — also forces a
  rebuild, because the Dockerfile copies the whole context.
- **`--skip-transfer`** now means "build locally only". Use it to warm the
  build; nothing on the NAS is touched.
- **Cert permissions are intentional.** `/volume1/docker/chatwoot/certs/apple_pay`
  is bind-mounted read-only into containers running as uid 1000 (`chatwoot`),
  and `merchant_session_service.rb` loads `apple_pay_private.key` at runtime, so
  the files must stay `644`/dir `755`. Locking them to `mdu` would break Apple
  Pay. Hardening (needs root, and future cert syncs would then need root too):
  `ssh -p 24 mdu@taborator.rhaps.net 'sudo chown -R 1000:1000 <dir> && sudo chmod -R go-rwx <dir>'`.
  The script prints this reminder at the end of every deploy.
- **`.env.production` is mode 600** and read by compose as `mdu`. Any other NAS
  account can no longer read the secrets.
- **Remote compose** may be `docker compose` (plugin) or `docker-compose`
  (legacy). The script prints which it picked; use that form in manual commands.
- **First-time cloudflared setup** is manual (one-off): connect the container to
  `cloudflare_rhaps_prod_net` and point the tunnel ingress at `http://web:8080`.
- **Memory:** compose limits total ≈ 4.8 GB (web 2g + worker 2g + postgres 512m +
  redis 256m) on a DS220+ that ships with 2 GB. Sidekiq is the usual OOM victim;
  align the limits with the installed RAM if workers get killed.

## Known follow-ups (not done)

- Rollback: images are only tagged `chatwoot:nas-web` / `nas-worker`, so the
  previous build is lost on redeploy. Tagging with the short SHA would allow a
  rollback and let old layers be pruned.
- No post-deploy smoke test (`curl -fsS https://msp.rhaps.net/`) before the
  success banner.
- No `docker image prune` on the NAS — every deploy leaves a dangling image on a
  small volume.
- No pre-flight validation of required env keys (`POSTGRES_PASSWORD`,
  `REDIS_PASSWORD`, `SECRET_KEY_BASE`); missing values surface only on the NAS.
- `docs/sync/v4.19.1/UPGRADE_PLAN.md` records upstream at Node `24.22.1`, so a
  future upstream sync may reintroduce the vulnerable pin — re-bump at merge time.
