# Chatwoot Documentation

This directory contains comprehensive documentation for the Chatwoot project, organized by topic.

## 📁 Directory Structure

### `/apple-messages/`
Apple Messages for Business (AMB) implementation documentation, including:
- Case normalization specifications
- Migration guides
- Webhook implementation
- Apple Pay integration
- Payload validation
- Phase completion reports

**Subdirectories:**
- `fixes/` - Bug fixes and troubleshooting documentation
- `guides/` - Setup and configuration guides
- `implementation/` - Feature implementation details
- `phases/` - Phase completion reports and milestones
- `scripts/` - Utility scripts (debug, test, utilities)
- `testing/` - Test documentation and results
- `data/` - Data files and references

**Key Files:**
- [`README.md`](apple-messages/README.md) - Overview of AMB features
- [`case-normalization-specification.md`](apple-messages/case-normalization-specification.md) - CaseTransformer specification
- [`APPLE_PAY_GUIDE.md`](apple-messages/APPLE_PAY_GUIDE.md) - Apple Pay integration guide
- [`MIGRATION_GUIDE.md`](apple-messages/MIGRATION_GUIDE.md) - Step-by-step migration procedures
- [`PAYLOAD_VALIDATION_IMPLEMENTATION.md`](apple-messages/PAYLOAD_VALIDATION_IMPLEMENTATION.md) - Payload validation details

**Fixes:**
- [`fixes/WEBHOOK_JWT_FIX.md`](apple-messages/fixes/WEBHOOK_JWT_FIX.md) - Webhook JWT authentication fix

**Phase Reports:**
- [`phases/PHASE_1_COMPLETE.md`](apple-messages/phases/PHASE_1_COMPLETE.md) - Phase 1 implementation details
- [`phases/PHASE_3_COMPLETE.md`](apple-messages/phases/PHASE_3_COMPLETE.md) - Phase 3 service layer cleanup
- [`phases/MIGRATION_IMPLEMENTATION_COMPLETE.md`](apple-messages/phases/MIGRATION_IMPLEMENTATION_COMPLETE.md) - Phase 2 migration guide

**Implementation:**
- [`implementation/APPLE_MSP_COMPLETE_IMPLEMENTATION_GUIDE.md`](apple-messages/implementation/APPLE_MSP_COMPLETE_IMPLEMENTATION_GUIDE.md) - Complete MSP implementation
- [`implementation/APPLE_MESSAGES_LIST_PICKER_IMPLEMENTATION.md`](apple-messages/implementation/APPLE_MESSAGES_LIST_PICKER_IMPLEMENTATION.md) - List picker implementation
- [`implementation/APPLE_RICH_LINK_FAVICON_IMPLEMENTATION.md`](apple-messages/implementation/APPLE_RICH_LINK_FAVICON_IMPLEMENTATION.md) - Rich link implementation
- [`implementation/APPLE_TYPING_INDICATOR_IMPLEMENTATION.md`](apple-messages/implementation/APPLE_TYPING_INDICATOR_IMPLEMENTATION.md) - Typing indicator implementation

**Guides:**
- [`guides/APPLE_MESSAGES_OAUTH2_APPLEPAY_CONFIGURATION_GUIDE.md`](apple-messages/guides/APPLE_MESSAGES_OAUTH2_APPLEPAY_CONFIGURATION_GUIDE.md) - OAuth2 and Apple Pay setup
- [`guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md`](apple-messages/guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md) - Troubleshooting common issues
- [`guides/CHATWOOT_MESSAGING_CHANNEL_GUIDE.md`](apple-messages/guides/CHATWOOT_MESSAGING_CHANNEL_GUIDE.md) - Messaging channel configuration

### `/bot-migration/`
Documentation for migrating the old Acoustic House Flask/Python bot to Chatwoot's bot system.

**Files:**
- [`APPLE_BOT_MIGRATION_GUIDE.md`](bot-migration/APPLE_BOT_MIGRATION_GUIDE.md) - Step-by-step migration guide
- [`COMPLETE_MIGRATION_SUMMARY.md`](bot-migration/COMPLETE_MIGRATION_SUMMARY.md) - Complete migration toolkit summary
- [`ACOUSTIC_HOUSE_FILTER_RESULTS.md`](bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md) - Core vs test template filtering results
- [`DRY_RUN_REFERENCE.md`](bot-migration/DRY_RUN_REFERENCE.md) - Dry-run mode examples
- [`n8n-bot-migration-analysis.md`](../archive/n8n-legacy/docs/bot-migration/n8n-bot-migration-analysis.md) - Technical analysis of old bot (archived, n8n integration retired)

### `/templates/`
Documentation for template import, fixes, and troubleshooting.

**Subdirectories:**
- `fixes/` - Template-related bug fixes and troubleshooting

**Key Files:**
- [`README.md`](templates/README.md) - Template system overview
- [`MESSAGETEMPLATE_ARCHITECTURE.md`](templates/MESSAGETEMPLATE_ARCHITECTURE.md) - Template architecture documentation
- [`MESSAGETEMPLATE_API_REFERENCE.md`](templates/MESSAGETEMPLATE_API_REFERENCE.md) - Template API reference
- [`BOT_RENDERER_VERIFICATION_REPORT.md`](templates/BOT_RENDERER_VERIFICATION_REPORT.md) - Bot renderer verification results
- [`GUITAR_FORM_TEMPLATE.md`](templates/GUITAR_FORM_TEMPLATE.md) - Guitar form template example
- [`SENDING_FILES_VIA_BOT_API.md`](../archive/n8n-legacy/docs/templates/SENDING_FILES_VIA_BOT_API.md) - File sending via bot API (archived, uses n8n as example client)
- [`TEMPLATE_ATTACHMENT_TESTS.md`](templates/TEMPLATE_ATTACHMENT_TESTS.md) - Template attachment test documentation
- [`TEMPLATE_ATTACHMENT_TESTS_SUMMARY.md`](templates/TEMPLATE_ATTACHMENT_TESTS_SUMMARY.md) - Test implementation summary
- [`TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md`](templates/TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md) - Quick reference guide

**Fixes:**
- [`fixes/FIX_TEMPLATES_NOT_SHOWING.md`](templates/fixes/FIX_TEMPLATES_NOT_SHOWING.md) - Fix for templates not appearing in UI
- [`fixes/BLOCK_EDITOR_FIX.md`](templates/fixes/BLOCK_EDITOR_FIX.md) - Block editor UI fixes
- [`fixes/GUITAR_FORM_FIXES.md`](templates/fixes/GUITAR_FORM_FIXES.md) - Guitar form fixes summary
- [`fixes/TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md`](templates/fixes/TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md) - Template editor image display fix
- [`fixes/TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md`](templates/fixes/TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md) - Template migration image format fix

### `/n8n/`
n8n workflow automation integration with Chatwoot.

**Files:**
- [`n8n-bot-integration-guide.md`](n8n/n8n-bot-integration-guide.md) - Complete n8n integration guide
- [`n8n-quick-reply-routing-example.md`](n8n/n8n-quick-reply-routing-example.md) - Quick reply response routing examples
- [`N8N_PRODUCTION_SETUP.md`](n8n/N8N_PRODUCTION_SETUP.md) - Production setup guide
- [`CUSTOM_NODES_FIXED.md`](n8n/CUSTOM_NODES_FIXED.md) - Custom nodes fixes
- [`NODE_STATUS_REPORT.md`](n8n/NODE_STATUS_REPORT.md) - Node status tracking
- [`NETWORK_AND_ICONS_SETUP.md`](n8n/NETWORK_AND_ICONS_SETUP.md) - Network and icons configuration

### `/deployment/`
Production deployment documentation and procedures.

**Files:**
- [`DEPLOYMENT_SUMMARY.md`](deployment/DEPLOYMENT_SUMMARY.md) - Production deployment summary and scripts

### `/development/`
Development guidelines and code review standards.

**Files:**
- [`CODE_REVIEW_GUIDELINES.md`](development/CODE_REVIEW_GUIDELINES.md) - Code review best practices

### `/guides/`
General setup and implementation guides.

**Files:**
- [`AMB_IMPLEMENTATION_SUMMARY.md`](guides/AMB_IMPLEMENTATION_SUMMARY.md) - Chatwoot codebase architecture analysis
- [`CAPTAIN_SETUP_GUIDE.md`](guides/CAPTAIN_SETUP_GUIDE.md) - Captain AI feature setup
- [`BOT_INTEGRATION_GUIDE.md`](guides/BOT_INTEGRATION_GUIDE.md) - Bot integration guide
- [`TEMPLATE_MIGRATION_GUIDE.md`](guides/TEMPLATE_MIGRATION_GUIDE.md) - Template migration guide
- [`UNIFIED_TEMPLATE_SYSTEM_ARCHITECTURE.md`](guides/UNIFIED_TEMPLATE_SYSTEM_ARCHITECTURE.md) - Template system architecture

### `/api/`
API documentation and specifications.

**Files:**
- [`BOT_TEMPLATES_API.md`](api/BOT_TEMPLATES_API.md) - Bot templates API documentation
- [`TEMPLATE_SCHEMA_REFERENCE.md`](api/TEMPLATE_SCHEMA_REFERENCE.md) - Template schema reference

### `/backups/`
Backup files and rollback scripts.

## 🚀 Quick Start Guides

### For Apple Messages for Business
1. Start with [`apple-messages/README.md`](apple-messages/README.md)
2. Review [`apple-messages/case-normalization-specification.md`](apple-messages/case-normalization-specification.md)
3. For Apple Pay: [`apple-messages/APPLE_PAY_GUIDE.md`](apple-messages/APPLE_PAY_GUIDE.md)
4. For troubleshooting: [`apple-messages/guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md`](apple-messages/guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md)

### For Bot Migration
1. Read [`bot-migration/APPLE_BOT_MIGRATION_GUIDE.md`](bot-migration/APPLE_BOT_MIGRATION_GUIDE.md)
2. Review [`bot-migration/COMPLETE_MIGRATION_SUMMARY.md`](bot-migration/COMPLETE_MIGRATION_SUMMARY.md)
3. Check filtering results: [`bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md`](bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md)

### For n8n Integration
1. Follow [`n8n/n8n-bot-integration-guide.md`](n8n/n8n-bot-integration-guide.md)
2. For quick replies: [`n8n/n8n-quick-reply-routing-example.md`](n8n/n8n-quick-reply-routing-example.md)
3. Production setup: [`n8n/N8N_PRODUCTION_SETUP.md`](n8n/N8N_PRODUCTION_SETUP.md)

### For Template Issues
1. Templates not showing: [`templates/fixes/FIX_TEMPLATES_NOT_SHOWING.md`](templates/fixes/FIX_TEMPLATES_NOT_SHOWING.md)
2. Block editor issues: [`templates/fixes/BLOCK_EDITOR_FIX.md`](templates/fixes/BLOCK_EDITOR_FIX.md)
3. Guitar form issues: [`templates/fixes/GUITAR_FORM_FIXES.md`](templates/fixes/GUITAR_FORM_FIXES.md)
4. Image display problems: [`templates/fixes/TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md`](templates/fixes/TEMPLATE_EDITOR_IMAGE_DISPLAY_FIX.md)
5. Image format migration: [`templates/fixes/TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md`](templates/fixes/TEMPLATE_MIGRATION_IMAGE_FORMAT_FIX.md)

### For Template Development
1. Architecture overview: [`templates/MESSAGETEMPLATE_ARCHITECTURE.md`](templates/MESSAGETEMPLATE_ARCHITECTURE.md)
2. API reference: [`templates/MESSAGETEMPLATE_API_REFERENCE.md`](templates/MESSAGETEMPLATE_API_REFERENCE.md)
3. Attachment tests: [`templates/TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md`](templates/TEMPLATE_ATTACHMENT_TESTS_QUICK_REFERENCE.md)

### For Deployment
1. Review [`deployment/DEPLOYMENT_SUMMARY.md`](deployment/DEPLOYMENT_SUMMARY.md)

## 📝 Key Concepts

### CaseTransformer
**CRITICAL**: ALL Apple Messages for Business code MUST use `AppleMessagesForBusiness::CaseTransformer` for case conversions.

- **Internal storage**: Always snake_case (Rails convention)
- **Frontend**: Naturally sends camelCase (JavaScript convention)
- **API boundary**: Automatic normalization (camelCase → snake_case)
- **Apple MSP boundary**: CaseTransformer (snake_case → camelCase)

See: [`apple-messages/case-normalization-specification.md`](apple-messages/case-normalization-specification.md)

### Template System
Chatwoot uses a unified template system with:
- `MessageTemplate` - Database records
- `TemplateContentBlock` - Content blocks
- `TemplateChannelMapping` - Channel-specific mappings

See: [`guides/UNIFIED_TEMPLATE_SYSTEM_ARCHITECTURE.md`](guides/UNIFIED_TEMPLATE_SYSTEM_ARCHITECTURE.md)

## 🔧 Development Workflow

### Build & Test
```bash
# Setup
bundle install && pnpm install

# Development Server
./script//dev-server.sh start          # localhost only
./script//dev-server.sh start-public   # with public access

# Linting
pnpm eslint:fix               # JavaScript/Vue
bundle exec rubocop -a        # Ruby

# Testing
pnpm test                     # JavaScript
bundle exec rspec spec/path   # Ruby
```

### Database Access
**NEVER use `psql` directly** - Claude Code runs in a sandbox that blocks direct PostgreSQL access.

**ALWAYS use `rails runner`**:
```bash
rails runner "puts User.count"
rails runner "puts Message.last.inspect"
```

### Deployment
**NEVER run deployment scripts through Claude Code** - SSH and rsync are blocked by sandbox.

**User must run manually**:
```bash
./script/deploy-production-docker.sh
./script/deploy-assets-only.sh
```

## 📚 Additional Resources

- **Project Root**: `/Users/rhaps/LocalGit/chatwoot`
- **Scripts**: `../script/` directory
- **Enterprise**: `../enterprise/` directory

## 🤝 Contributing

When adding new documentation:
1. Place in the appropriate subdirectory
2. Update this README with links
3. Use clear, descriptive filenames
4. Include a summary at the top of each document
5. For bug fixes: place in the `fixes/` subdirectory
6. For phase completions: place in the `phases/` subdirectory

## 📄 License

This documentation is part of the Chatwoot project.
