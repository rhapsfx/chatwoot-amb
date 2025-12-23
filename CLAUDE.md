# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `./script/dev-server.sh start` (localhost only) or `./script/dev-server.sh start-public` (with public access)
- **Server Management**: `./script/dev-server.sh {start|start-public|stop|restart|status|help}`
- **Public Access Options**: Custom domain, Tailscale Funnel, or ngrok (configured in dev-server.sh)
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Legacy Run**: `overmind start -f Procfile.dev` (use dev-server.sh instead)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don't write multiple versions or backups for the same logic — pick the best approach and implement it
- Don't reference Claude in commit messages

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

**Practical checklist for any change impacting core logic or public APIs**:
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- Remember that any tailscale command as privilege Claude cannot use, please ask me directly to execute them
- Keep in memory the Vue configuration requirement

## Apple Messages for Business (AMB)

**📚 Complete Documentation**: See [`docs/apple-messages/AMB_DEVELOPMENT_GUIDE.md`](docs/apple-messages/AMB_DEVELOPMENT_GUIDE.md)

### Critical Rules

**🚨 MANDATORY Requirements**:

1. **CaseTransformer Usage**:
   - ALL AMB code MUST use [`CaseTransformer`](app/services/apple_messages_for_business/case_transformer.rb) for case conversions
   - Internal storage: Always snake_case
   - Apple MSP API: Always camelCase (via CaseTransformer)
   - NEVER use dual-checks: `field['snake_case'] || field['camelCase']` ❌

2. **Template Access**:
   - MUST use [`TemplateFacade`](app/services/apple_messages_for_business/template_facade.rb) for all template data access
   - Use `load_data_with_images()` for bot sends (includes images automatically)
   - Use `load_data()` for UI display (images loaded separately)

3. **Image System**:
   - Three-tier fallback: Inbox-specific → Account-wide shared → Embedded
   - Implementation: [`ImageFetchService`](app/services/apple_messages_for_business/image_fetch_service.rb)
   - All identifiers stored in snake_case

**Quick Reference**:
```ruby
# Case conversion
AppleMessagesForBusiness::CaseTransformer.to_apple_format(data)

# Template with images (for bots)
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data_with_images('list_picker')

# Image fetching
service = AppleMessagesForBusiness::ImageFetchService.new(
  account_id: account.id,
  inbox_id: inbox.id,  # nil for bot sends
  embedded_images: []
)
images = service.fetch_and_encode(['identifier1', 'identifier2'])
```

**Architecture Documentation**:
- [`AMB_INTEGRATION_STATUS_REPORT.md`](docs/apple-messages/AMB_INTEGRATION_STATUS_REPORT.md) - Complete system overview
- [`AMB_DEPENDENCY_MAP.md`](docs/apple-messages/AMB_DEPENDENCY_MAP.md) - Visual dependency guide

## Bot Studio

**📚 Complete Documentation**: See [`docs/bot-studio/BOT_STUDIO_GUIDE.md`](docs/bot-studio/BOT_STUDIO_GUIDE.md)

### Critical Rules

**🚨 Flow Activation Requirement**:
- Flows MUST have BOTH `is_active: true` AND `is_published: true` to execute
- Without both flags, system falls back to legacy handlers

**Activating Flows**:
```bash
# For existing flows
rails runner script/activate_master_bot_flow.rb

# Verify in logs
✅ CORRECT: [Bot] 🚀 Using FlowExecutorService for visual bot flow
❌ INCORRECT: [Bot] 📜 No active flow found - using legacy AcousticHouseBotService
```

**Important**: Bot 18 ("Acoustic House Master Bot") is a **reference/demo bot** showcasing all 12 template types, NOT a working conversational bot (intent nodes have no keywords).

## Database Access - CRITICAL

**🚨 ABSOLUTE RULE: NEVER attempt direct PostgreSQL access via `psql` or connection strings**

Claude Code runs in a macOS sandbox that **ALWAYS BLOCKS** direct database connections. This will ALWAYS fail.

**✅ ONLY use these methods for ALL database operations**:

1. **`rails runner`** - For quick queries and scripts:
   ```bash
   rails runner "puts User.count"
   rails runner "puts Message.last.inspect"
   rails runner "script/some_script.rb"
   ```

2. **`rails console`** - For interactive exploration:
   ```bash
   rails console
   # Then run queries interactively
   ```

3. **Ruby scripts executed via `rails runner`** - For complex operations:
   ```ruby
   # Create script/my_query.rb, then:
   rails runner script/my_query.rb
   ```

**❌ NEVER do**:
- `/opt/homebrew/opt/postgresql@15/bin/psql` (WILL FAIL - sandbox blocks it)
- Direct database connections
- `ActiveRecord::Base.connection.execute` outside of rails runner context
- Any attempt to bypass Rails to access PostgreSQL

**Remember**: The sandbox restriction is PERMANENT and CANNOT be bypassed. Always work through Rails.

## Rails Command Execution Policy - CRITICAL

**🚨 ABSOLUTE RULE: NEVER run Rails commands directly without explicit user approval**

Rails commands can modify database state, trigger side effects, or perform operations that the user should review first.

**✅ ALWAYS follow this workflow**:

1. **For simple Rails commands** - Provide the command to the user:
   ```bash
   # Example: Tell the user to run
   rails runner "puts Message.where(message_type: :incoming).count"
   ```

2. **For complex Rails operations** - Create a script file and provide instructions:
   ```ruby
   # Create script/analyze_custom_payload.rb with the logic
   # Then tell the user: "Please run: rails runner script/analyze_custom_payload.rb"
   ```

3. **For multi-step operations** - Create a documented script:
   ```ruby
   # script/migrate_data.rb
   # Purpose: Migrate old format to new format
   # Usage: rails runner script/migrate_data.rb [--dry-run]

   # [Script implementation here]
   ```

**Exceptions (require user context/approval)**:
- ✅ Read-only queries that were explicitly requested
- ✅ Running tests (`bundle exec rspec`)
- ✅ Linting/formatting commands
- ✅ Log file inspection

**❌ NEVER run without approval**:
- Database modifications (`rails runner "Model.update_all(...)"`)
- Data migrations or transformations
- Service calls that trigger external APIs
- Any operation with side effects

**Why This Rule**:
- User maintains control over database changes
- Scripts can be reviewed before execution
- Operations can be run with appropriate timing
- User can verify preconditions are met
- Enables dry-run testing

**Best Practice**:
```
❌ BAD: Directly run rails runner "complex operation"
✅ GOOD: Create script/operation.rb and say "Please run: rails runner script/operation.rb"
```

## Remote Server Deployment

**📚 Complete Documentation**: See [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md)

**Production Server**: msp.rhaps.net (Docker-based deployment)
**Development Server**: liquid-m3-pro.tail367da4.ts.net (Tailscale Funnel via `script/dev-server.sh`)

### Deployment Scripts Overview

| Scenario | Script | Time | When to Use |
|----------|--------|------|-------------|
| Backend code only (Ruby) | `./script/deploy-backend-enhanced.sh` | 1-3 min | Services, controllers, models, routes, migrations |
| Full rebuild | `./script/quick_rebuild.sh` | 5-15 min | Dependencies, frontend, Docker changes |
| Clean rebuild | `./script/quick_rebuild.sh --no-cache` | 15-20 min | Infrastructure changes, version updates |

### Quick Reference - Common Scenarios

```bash
# Fix backend bug (Ruby code only)
./script/deploy-backend-enhanced.sh

# Add new gem dependency
./script/quick_rebuild.sh

# Update frontend UI
./script/quick_rebuild.sh

# Update Dockerfile configuration
./script/quick_rebuild.sh --no-cache

# Deploy with database migration
./script/deploy-backend-enhanced.sh  # Runs migrations automatically
```

### Deployment Workflow

1. **Make changes locally**
2. **Test thoroughly**:
   ```bash
   bundle exec rspec                    # Run tests
   bundle exec rubocop -a               # Check/fix Ruby style
   pnpm eslint:fix                      # Check/fix JS style
   ./script/dev-server.sh start         # Test locally
   ```
3. **Commit changes**:
   ```bash
   git add .
   git commit -m "Fix: Description of change"
   git push
   ```
4. **Choose appropriate deployment script** (see decision tree in [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md))
5. **Verify deployment**:
   ```bash
   # Check container status
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'
   
   # Check application health
   curl https://msp.rhaps.net/health
   
   # View logs
   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web'
   ```

### Important Notes

- **NEVER run deployment scripts through Claude** - SSH and rsync are blocked by sandbox
- **ALWAYS ask user to run deployment scripts manually** in their terminal
- **Always commit before deploying** - Version control is critical for rollbacks
- **Choose the right script** - Using `quick_rebuild.sh` for simple code changes wastes 10+ minutes
- **Monitor during deployment** - Watch logs in separate terminal to catch issues early
- **Verify after deployment** - Check container health, application endpoints, and feature functionality

### Container Management

```bash
# Check running containers
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'

# Restart specific service
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml restart worker'

# View service logs
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'

# Update and recreate service
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d --force-recreate worker'
```

### Local Development Server

**Script**: `script/dev-server.sh`
**Domain**: liquid-m3-pro.tail367da4.ts.net (Tailscale Funnel)
**Management**: `./script/dev-server.sh {start|start-public|stop|restart|status|help}`

The dev server automatically:
- Sets `HOSTNAME="liquid-m3-pro-dev"` for Sidekiq identification
- Manages Rails web server and Sidekiq worker
- Provides public access via Tailscale Funnel when using `start-public`