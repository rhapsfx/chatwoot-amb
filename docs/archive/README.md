# Archive

Retired systems and superseded docs. Nothing here describes current behaviour —
it is kept for history and for understanding why the code looks the way it does.

| Directory / file | What it is |
| --- | --- |
| [`bot-migration/`](bot-migration/) | Flask/Python bot → Chatwoot bot migration: guide, dry-run reference, template-filter results |
| [`analysis-results.txt`](analysis-results.txt) | Dry-run output from the Apple Messages content-attributes normalization |

The retired workflow-automation toolchain was deleted on 2026-11-15 at the
owner's request; only the migration write-up in [`bot-migration/`](bot-migration/)
remains, because it explains how the current Ruby bot service behaves.

## Rules

- Add a `> Archived <date> — <reason>` line at the top of anything moved here if
  it does not already say so.
- Links inside archived docs are frozen: the known-dead ones are baselined in
  `script/docs-links-baseline.txt`, and the link checker will flag any *new* one.
  Prefer not to link into `archive/` from live docs — quote the conclusion instead.
