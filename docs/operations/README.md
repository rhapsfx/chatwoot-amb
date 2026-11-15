# Operations

Runtime behaviour that isn't tied to a single feature: what gets logged, how
logs are stored, and the diagnostics used in production.

| Doc | Purpose |
| --- | --- |
| [`log-sanitization.md`](log-sanitization.md) | Canonical log sanitization design: what is redacted, where the filters hook in |
| [`log-archiving.md`](log-archiving.md) | Log archiving + cleanup feature: retention, storage layout, tasks |
| [`amb-log-diagnostics.md`](amb-log-diagnostics.md) | Production log diagnostic scripts for AMB (what to grep, when) |
| [`archive/`](archive/) | Superseded sanitization designs kept for history — do not follow these |

## History

The log sanitization work went through several iterations (final solution,
unified solution, Sidekiq-specific fix, implementation summary, nil-log filter).
Those copies are preserved in [`archive/`](archive/) with this note; the
canonical description is [`log-sanitization.md`](log-sanitization.md). When
changing behaviour, edit the canonical doc and add a dated line to its history
section instead of creating `-v2`, `-final`, `-unified` files.

## Related code

- `app/controllers/concerns/log_sanitizable.rb` — controller-side filtering
- `app/services/log_sanitizer_service.rb` — shared sanitizer
- `app/services/apple_messages_for_business/log_sanitizer.rb` — AMB payload redaction
- `config/initializers/` — Rails logger / Sidekiq log formatting
