# Archived: n8n integration (legacy)

This directory holds the n8n-based Apple Messages for Business integration, archived
because it was a legacy integration test superseded by the in-repo Ruby bot service
(`app/services/apple_messages_for_business/`).

## Contents

- `n8n-nodes-chatwoot-amb/` - the n8n community node package (Apple Pay, List Picker,
  Time Picker, Form, Quick Reply, Rich Link, File Attachment nodes)
- `docs/bot-migration/n8n-bot-migration-analysis.md` - analysis of the original n8n bot
- `docs/apple-messages/CHATWOOT_BOT_INTEGRATION_PROPOSAL.md` - proposal to replace the
  n8n workflow with a Ruby bot service
- `docs/apple-messages/README_BOT_SERVICE.md` - overview of the resulting Ruby bot service
- `docs/apple-messages/RUBY_BOT_SERVICE_GUIDE.md` - technical guide for the Ruby bot service
- `docs/templates/SENDING_FILES_VIA_BOT_API.md` - file attachment guide, written with n8n
  as the example Bot API client

An `n8n-legacy.zip` archive of this directory is kept alongside it at `archive/n8n-legacy.zip`.
