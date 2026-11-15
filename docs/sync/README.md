# Upstream Sync

Artifacts from pulling upstream Chatwoot into this fork, which carries the Apple
Messages for Business work. Each sync leaves behind its planning docs and the
raw merge inventories so the next one can compare.

| Entry | Purpose |
| --- | --- |
| [`prod-sync-guide.md`](prod-sync-guide.md) | How to retrieve the production source + data from `msp.rhaps.net` before a sync |
| [`phase-7-summary.md`](phase-7-summary.md) | v4.12 → v4.13.0 sync, phase-by-phase record |
| [`v4.13.0/`](v4.13.0/) | Merge inventories: `upstream_only_files.txt`, `conflict_files.txt`, `amb_only_files.txt` |
| [`v4.17.0/`](v4.17.0/) | Same, plus `phase0_*` checkout/rename/deletion lists and full diff name-status |
| [`v4.19.1/`](v4.19.1/) | Most complete set: `UPGRADE_PLAN.md`, `PR_DESCRIPTION.md`, conflict and migration lists |

## Post-sync guard

`script/check_amb_sync.sh` verifies the AMB invariants documented in
`phase-7-summary.md` and `v4.19.1/UPGRADE_PLAN.md` still hold. Run it after every
upstream merge:

```bash
script/check_amb_sync.sh
```

## Adding a new sync

Create `vX.Y.Z/` here and drop the raw `*_files.txt` / diff inventories in
verbatim (they are cheap and make conflict review repeatable). Keep the plan and
PR description alongside them; do not put them at the docs root.
