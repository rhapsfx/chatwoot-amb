# Chatwoot Documentation

Internal documentation for this fork (Chatwoot + Apple Messages for Business,
self-hosted on the Synology NAS). Upstream product documentation lives at
<https://www.chatwoot.com/docs>.

> Keep this file a **hub**, not an inventory. Every area owns its own `README.md`;
> a hand-maintained list of every file is what made the old index rot (54% of its
> links were dead). Adding a doc? Add it to its area README, not here.

## Start here

| I want to… | Read |
| --- | --- |
| Deploy to the NAS | [`deployment/nas/README.md`](deployment/nas/README.md) |
| Understand the other deploy scripts | [`deployment/deployment-guide.md`](deployment/deployment-guide.md) |
| Fix a failing Docker build | [`deployment/docker-build-troubleshooting.md`](deployment/docker-build-troubleshooting.md) |
| Work on Apple Messages for Business | [`apple-messages/README.md`](apple-messages/README.md) |
| Work on message templates | [`templates/MESSAGETEMPLATE_ARCHITECTURE.md`](templates/MESSAGETEMPLATE_ARCHITECTURE.md) |
| Sync from upstream Chatwoot | [`sync/prod-sync-guide.md`](sync/prod-sync-guide.md) |
| Debug logging / log storage | [`operations/log-sanitization.md`](operations/log-sanitization.md) |

## Areas

| Area | What lives there | Files |
| --- | --- | --- |
| [`deployment/`](deployment/README.md) | Deploy scripts, NAS workflow, Docker build issues | 4 |
| [`operations/`](operations/README.md) | Runtime behaviour: logging, sanitization, archiving, diagnostics | 10 |
| [`apple-messages/`](apple-messages/README.md) | The AMB integration: guides, implementation plans, scripts, data | 89 |
| [`templates/`](templates/README.md) | MessageTemplate system, renderer/adapters, tests | 11 |
| [`features/`](features/README.md) | Cross-cutting features: shared images, bots, Captain, Apple Store logo | 9 |
| [`reference/`](reference/README.md) | API contracts, dev guidelines, Rails upgrade notes | 7 |
| [`sync/`](sync/README.md) | Upstream sync guides and per-version merge artifacts | 27 |
| [`archive/`](archive/README.md) | Retired systems and superseded docs | 5 |

## Conventions

- **One canonical doc per topic.** When a doc is superseded, add a 3-line header
  (`> Superseded by … on YYYY-MM-DD`) and move it under the area's `archive/` or
  `docs/archive/`. Do not keep two live copies.
- **Filenames are kebab-case** (`nas-deployment-guide.md`), `SCREAMING_CASE` only
  for `README.md`. Legacy names in `apple-messages/` are left as-is; new files
  follow the rule.
- **Version/date-specific material** goes under `sync/vX.Y.Z/` or `archive/`,
  never the root.
- **Area README = index.** Each area README lists its own files (name + purpose).
  The root README links areas only.
- **Dates beat pronouns.** Record *when* something was verified or decided
  ("verified 2026-11-15"), not just what it says.

## Maintenance

```bash
./script/check-docs-links.sh                    # fails on NEW broken relative links
./script/check-docs-links.sh --list             # every broken link
./script/check-docs-links.sh --update-baseline  # accept current state (review the diff first)
```

`script/docs-links-baseline.txt` holds the known-dead links (`docs/apple-messages/`
guides and the `apple-messages/` implementation plans still have many). Shrink it
as areas get cleaned up; the checker keeps it from growing.

Note: `docs/` is excluded from the Docker build context (`.dockerignore`), so
relative links here are read on GitHub/editors only — they are never served by
the app.
