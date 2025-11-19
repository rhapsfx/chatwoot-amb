# Chatwoot Codebase Analysis Summary

## 🏗️ **Architecture Overview**

**Chatwoot** is a **Rails 7.0** customer engagement platform with a **Vue.js 3** frontend, featuring extensive **Apple Messages for Business (AMB)** integration. The codebase follows a modular architecture with clear separation between OSS and Enterprise editions.

---

## 📊 **Core Technology Stack**

### Backend (Ruby on Rails)
- **Framework**: Rails 7.0 with Ruby
- **Database**: PostgreSQL with ActiveRecord
- **Background Jobs**: Sidekiq
- **Search**: Searchkick (optional advanced search)
- **Monitoring**: Multiple APM options (Datadog, Elastic APM, Scout, New Relic, Sentry)
- **Autoscaling**: Judoscale for Heroku
- **Security**: Active Record Encryption for MFA/2FA features

### Frontend (Vue.js)
- **Framework**: Vue 3 with Composition API (`<script setup>`)
- **Styling**: Tailwind CSS (exclusively - no custom CSS)
- **I18n**: vue-i18n for internationalization
- **Date Handling**: date-fns and date-fns-tz
- **State Management**: Vue reactive refs and computed properties

---

## 🎯 **Key Architectural Patterns**

### 1. **Enterprise Overlay Architecture**
```
app/                    # OSS core
enterprise/app/         # Enterprise extensions
enterprise/lib/         # Enterprise libraries
enterprise/listeners/   # Enterprise event listeners
```
- Enterprise code extends/overrides OSS via eager loading
- Views can be overridden by placing in `enterprise/app/views`
- Initializers loaded from both trees

### 2. **Message Model (Central Entity)**
**Complexity**: Medium | **Lines**: 200+

**Key Features**:
- 22 content types including 9 Apple-specific types
- 4 message types: incoming, outgoing, activity, template
- 4 status states: sent, delivered, read, failed
- JSON storage for `content_attributes` and `external_source_ids`
- Polymorphic sender relationship
- Searchkick integration for advanced search
- Extensive validation and callbacks

**Apple Messages Content Types**:
- `apple_list_picker` (13)
- `apple_time_picker` (14)
- `apple_quick_reply` (15)
- `apple_pay` (16)
- `apple_rich_link` (17)
- `apple_authentication` (18)
- `apple_form` (19)
- `apple_custom_app` (20)
- `apple_form_response` (21)

### 3. **CaseTransformer Pattern (Critical for AMB)**
**Complexity**: Medium | **Lines**: 332

**Design Principle**:
```
Frontend (camelCase) 
  → API Controller (auto-normalizes to snake_case)
  → Database (snake_case storage)
  → Services (snake_case internally)
  → CaseTransformer (converts to camelCase)
  → Apple MSP API (camelCase)
```

**Key Components**:
- `TO_APPLE_MAPPINGS`: 100+ field mappings (snake_case → camelCase)
- `CONTEXT_MAPPINGS`: Context-aware transformations (received_message, reply_message)
- `PRESERVE_KEYS`: Apple MSP standard fields (never transformed)
- Bidirectional transformation with automatic reverse mapping
- Recursive value transformation for nested structures

**Critical Rule**: ALL Apple Messages code MUST use CaseTransformer - no dual-checks like `field['snake_case'] || field['camelCase']`

### 4. **Messages Controller Pattern**
**Complexity**: Medium

**Key Features**:
- Automatic case normalization via `before_action`
- Apple Messages processor for URL-to-Rich Link conversion
- Dual-path message creation (Apple vs. regular)
- Translation support via Google Translate integration
- Apple Pay request handling with validation
- Message retry mechanism with status updates

---

## 🍎 **Apple Messages for Business Integration**

### Service Architecture
```
AppleMessagesForBusiness::
  ├── CaseTransformer (case conversion)
  ├── MessageProcessorService (message processing)
  ├── SendListPickerService (list picker with images)
  ├── SendTimePickerService (time picker with images)
  ├── FormService (forms with images)
  ├── SendRichLinkService (rich links)
  └── SendApplePayService (Apple Pay)
```

### Image Management
- **Storage**: ActiveStorage with base64 encoding
- **Models**: `AppleListPickerImage`, `AppleTimePickerImage`
- **Automatic Fallback**: Reply images auto-sync with received images
- **Frontend**: Image selector with preview in modals

### Frontend Components (Vue 3)
**EnhancedTimePickerModal** - Complexity: Medium
- Business hours management with timezone support
- Time slot generation with interval options (15/30/60 min)
- Existing bookings conflict detection
- Image selection with automatic sync
- Date-fns for date manipulation
- Composition API with reactive state

---

## 🔧 **Development Workflow**

### Build & Test
```bash
# Setup
bundle install && pnpm install

# Development Server
./script//dev-server.sh start          # localhost only
./script//dev-server.sh start-public   # with public access (Tailscale/ngrok)

# Linting
pnpm eslint:fix               # JavaScript/Vue
bundle exec rubocop -a        # Ruby

# Testing
pnpm test                     # JavaScript
bundle exec rspec spec/path   # Ruby
```

### Database Access
**Critical**: Never use `psql` directly (sandbox blocked)
```bash
# Use rails runner instead
rails runner "puts User.count"
rails runner "puts Message.last.inspect"
```

### Deployment
**Critical**: Never run deployment scripts through Claude Code
```bash
# User must run manually:
./script/deploy-backend-changes-safe.sh
./script/deploy-assets-only.sh
./script/enable_custom_roles_production.sh
```

---

## 📝 **Code Style Guidelines**

### Ruby
- RuboCop rules (150 char max line length)
- Compact module/class definitions
- Strong params validation
- Custom exceptions in `lib/custom_exceptions/`

### Vue/JavaScript
- ESLint (Airbnb base + Vue 3 recommended)
- **Always** Composition API with `<script setup>`
- PascalCase for components
- camelCase for events
- No bare strings (use i18n)

### Styling
- **Tailwind ONLY** - no custom CSS, no scoped CSS, no inline styles
- Color definitions in `tailwind.config.js`

---

## 🎨 **Project-Specific Patterns**

### I18n
- Backend: `en.yml` only (community handles other languages)
- Frontend: `en.json` only
- No bare strings in templates

### Frontend Structure
- `components-next/` for message bubbles (active development)
- Legacy components being deprecated
- Modular component organization by feature

### Enterprise Development
- Check `enterprise/` for corresponding files before changes
- Use extension points (`prepend_mod_with`, hooks, config)
- Avoid hardcoding instance/plan-specific behavior in OSS
- Mirror changes in both trees when renaming/moving

---

## 📈 **Complexity Assessment**

| Component | Complexity | Key Characteristics |
|-----------|-----------|---------------------|
| Application Config | Medium | APM integration, encryption, enterprise loading |
| Message Model | Medium | 22 content types, extensive validations, polymorphic |
| CaseTransformer | Medium | 100+ mappings, context-aware, recursive |
| Messages Controller | Medium | Dual-path processing, translation, Apple Pay |
| TimePickerModal | Medium | Date manipulation, business hours, image sync |

---

## 🚀 **Key Strengths**

1. **Modular Architecture**: Clear separation of concerns with service objects
2. **Enterprise-Ready**: Overlay architecture allows clean OSS/Enterprise split
3. **Apple Integration**: Comprehensive AMB support with proper case handling
4. **Type Safety**: Strong validations and schema enforcement
5. **Internationalization**: Built-in i18n support throughout
6. **Modern Frontend**: Vue 3 Composition API with Tailwind CSS

---

## ⚠️ **Critical Implementation Notes**

1. **CaseTransformer is mandatory** for all AMB features
2. **No dual-case checks** - single source of truth
3. **Database access** only via rails runner (not psql)
4. **Deployment scripts** must be run by user (not Claude)
5. **Tailwind only** for styling - no exceptions
6. **Enterprise compatibility** must be maintained for core changes

---

## 📚 **Related Documentation**

- [Case Normalization Specification](apple-messages/case-normalization-specification.md)
- [Phase 1 Complete](apple-messages/PHASE_1_COMPLETE.md)
- [Migration Implementation Complete](apple-messages/MIGRATION_IMPLEMENTATION_COMPLETE.md)
- [Migration Guide](apple-messages/MIGRATION_GUIDE.md)

---

**Last Updated**: November 2025  
**Analysis Tool**: Apple Intelligence MCP `summarize-code`

This analysis covers the core architecture, key patterns, and critical implementation details of the Chatwoot codebase, with special emphasis on the Apple Messages for Business integration which represents a significant portion of the custom functionality.