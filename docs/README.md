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

**Key Files:**
- [`README.md`](apple-messages/README.md) - Overview of AMB features
- [`case-normalization-specification.md`](apple-messages/case-normalization-specification.md) - CaseTransformer specification
- [`APPLE_PAY_GUIDE.md`](apple-messages/APPLE_PAY_GUIDE.md) - Apple Pay integration guide

### `/bot-migration/`
Documentation for migrating the old Acoustic House Flask/Python bot to Chatwoot's bot system.

**Files:**
- [`APPLE_BOT_MIGRATION_GUIDE.md`](bot-migration/APPLE_BOT_MIGRATION_GUIDE.md) - Step-by-step migration guide
- [`APPLE_BOT_MIGRATION_SUMMARY.md`](bot-migration/APPLE_BOT_MIGRATION_SUMMARY.md) - Executive summary
- [`COMPLETE_MIGRATION_SUMMARY.md`](bot-migration/COMPLETE_MIGRATION_SUMMARY.md) - Complete migration toolkit summary
- [`ACOUSTIC_HOUSE_FILTER_RESULTS.md`](bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md) - Core vs test template filtering results
- [`DRY_RUN_REFERENCE.md`](bot-migration/DRY_RUN_REFERENCE.md) - Dry-run mode examples
- [`n8n-bot-migration-analysis.md`](bot-migration/n8n-bot-migration-analysis.md) - Technical analysis of old bot

### `/templates/`
Documentation for template import, fixes, and troubleshooting.

**Files:**
- [`FIX_TEMPLATES_NOT_SHOWING.md`](templates/FIX_TEMPLATES_NOT_SHOWING.md) - Fix for templates not appearing in UI
- [`BLOCK_EDITOR_FIX.md`](templates/BLOCK_EDITOR_FIX.md) - Block editor UI fixes
- [`IMAGE_EXTRACTION_UPDATE.md`](templates/IMAGE_EXTRACTION_UPDATE.md) - Image extraction fixes for template editor
- [`ADDITIONAL_FIXES.md`](templates/ADDITIONAL_FIXES.md) - Additional template migration fixes

### `/n8n/`
n8n workflow automation integration with Chatwoot.

**Files:**
- [`n8n-bot-integration-guide.md`](n8n/n8n-bot-integration-guide.md) - Complete n8n integration guide
- [`n8n-quick-reply-routing-example.md`](n8n/n8n-quick-reply-routing-example.md) - Quick reply response routing examples

### `/deployment/`
Production deployment documentation and procedures.

**Files:**
- [`DEPLOYMENT_SUMMARY.md`](deployment/DEPLOYMENT_SUMMARY.md) - Production deployment summary and scripts

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

### `/backups/`
Backup files and rollback scripts.

## 🚀 Quick Start Guides

### For Apple Messages for Business
1. Start with [`apple-messages/README.md`](apple-messages/README.md)
2. Review [`apple-messages/case-normalization-specification.md`](apple-messages/case-normalization-specification.md)
3. For Apple Pay: [`apple-messages/APPLE_PAY_GUIDE.md`](apple-messages/APPLE_PAY_GUIDE.md)

### For Bot Migration
1. Read [`bot-migration/APPLE_BOT_MIGRATION_GUIDE.md`](bot-migration/APPLE_BOT_MIGRATION_GUIDE.md)
2. Review [`bot-migration/COMPLETE_MIGRATION_SUMMARY.md`](bot-migration/COMPLETE_MIGRATION_SUMMARY.md)
3. Check filtering results: [`bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md`](bot-migration/ACOUSTIC_HOUSE_FILTER_RESULTS.md)

### For n8n Integration
1. Follow [`n8n/n8n-bot-integration-guide.md`](n8n/n8n-bot-integration-guide.md)
2. For quick replies: [`n8n/n8n-quick-reply-routing-example.md`](n8n/n8n-quick-reply-routing-example.md)

### For Template Issues
1. Templates not showing: [`templates/FIX_TEMPLATES_NOT_SHOWING.md`](templates/FIX_TEMPLATES_NOT_SHOWING.md)
2. Block editor issues: [`templates/BLOCK_EDITOR_FIX.md`](templates/BLOCK_EDITOR_FIX.md)
3. Image problems: [`templates/IMAGE_EXTRACTION_UPDATE.md`](templates/IMAGE_EXTRACTION_UPDATE.md)

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
./dev-server.sh start          # localhost only
./dev-server.sh start-public   # with public access

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
./script/deploy-backend-changes-safe.sh
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

## 📄 License

This documentation is part of the Chatwoot project.