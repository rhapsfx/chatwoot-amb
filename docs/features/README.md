# Features

Cross-cutting feature documentation that is bigger than a single controller but
not AMB-specific.

| Doc | Purpose |
| --- | --- |
| [`shared-apple-images/`](shared-apple-images/) | Two-tier image architecture (`SharedAppleImage` / `AppleListPickerImage`): API, controller, tests, delivery manifest |
| [`bot-integration-guide.md`](bot-integration-guide.md) | Integrating external bots (Dialogflow, Rasa, custom) with Chatwoot |
| [`captain-setup-guide.md`](captain-setup-guide.md) | Enabling/operating the Captain AI feature |
| [`captain-v1-sunset.md`](captain-v1-sunset.md) | Captain V1 retirement notes for self-hosted installs |
| [`apple-store-logo.md`](apple-store-logo.md) | Apple Store logo upload flow |

## Shared Apple images

The image architecture replaced inbox-scoped images with account-wide
`SharedAppleImage` records (with `AppleListPickerImage` for per-inbox
overrides). Start with [`shared-apple-images/api.md`](shared-apple-images/api.md),
then the controller reference; the delivery manifest maps the test suite files.

Related AMB docs live in [`../apple-messages/`](../apple-messages/README.md)
(`IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`, `IMAGE_MIGRATION_GUIDE.md`,
`SHARED_IMAGES_USAGE.md`).
