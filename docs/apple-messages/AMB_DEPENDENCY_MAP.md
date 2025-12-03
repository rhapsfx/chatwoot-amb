# Apple Messages for Business - Dependency Map & Visual Guide

**Companion Document to**: AMB_INTEGRATION_STATUS_REPORT.md
**Generated**: 2025-11-28

---

## Component Dependency Graph

### Frontend → Backend Dependencies

```
┌───────────────────────────────────────────────────────────────────────┐
│                        FRONTEND LAYER                                  │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Vue Components (25+)                                                 │
│  ├─ AppleMessagesComposer.vue                                        │
│  │  ├─ Depends on: AppleMessagesButton.vue                          │
│  │  ├─ Depends on: Template API                                     │
│  │  └─ Emits: message data (camelCase)                              │
│  │                                                                   │
│  ├─ Message Bubbles (9 components)                                  │
│  │  ├─ AppleListPicker.vue                                          │
│  │  ├─ AppleTimePicker.vue                                          │
│  │  ├─ AppleForm.vue                                                │
│  │  ├─ AppleFormResponse.vue                                        │
│  │  ├─ AppleQuickReply.vue                                          │
│  │  ├─ ApplePayment.vue                                             │
│  │  ├─ AppleAuthentication.vue                                      │
│  │  ├─ AppleRichLink.vue                                            │
│  │  └─ AppleCustomApp.vue                                           │
│  │     └─ All receive: content_attributes (from API)                │
│  │                                                                   │
│  ├─ Modal Builders (5 components)                                   │
│  │  ├─ AppleFormBuilder.vue                                         │
│  │  │  ├─ Depends on: SharedImageSelector.vue                      │
│  │  │  ├─ Depends on: Template API                                 │
│  │  │  └─ Uses: useSharedAppleImages composable                    │
│  │  ├─ EnhancedTimePickerModal.vue                                 │
│  │  │  ├─ Depends on: SharedImageSelector.vue                      │
│  │  │  └─ Uses: useSharedAppleImages composable                    │
│  │  ├─ AppleAuthModal.vue                                          │
│  │  ├─ ApplePaymentModal.vue                                       │
│  │  └─ ApplePayloadModal.vue                                       │
│  │                                                                   │
│  ├─ Block Editors (4 components)                                    │
│  │  ├─ ListPickerBlockEditor.vue                                   │
│  │  ├─ TimePickerBlockEditor.vue                                   │
│  │  ├─ FormBlockEditor.vue                                         │
│  │  └─ QuickReplyBlockEditor.vue                                   │
│  │     └─ All depend on: Template API                              │
│  │                                                                   │
│  └─ Shared Components                                               │
│     ├─ SharedImageSelector.vue                                      │
│     │  ├─ Uses: useSharedAppleImages.js                            │
│     │  └─ Calls: Shared Images API                                 │
│     └─ AppleMessagesButton.vue                                      │
│                                                                      │
└──────────────────────────┬────────────────────────────────────────────┘
                           ↓
┌───────────────────────────────────────────────────────────────────────┐
│                         API LAYER                                      │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Controllers (7 controllers)                                          │
│  ├─ MessagesController                                               │
│  │  ├─ before_action: normalize_apple_messages_params               │
│  │  │  └─ Uses: CaseTransformer.from_apple_format                  │
│  │  ├─ Validates: ContentAttributeValidator                         │
│  │  └─ Routes to: SendMessageService                                │
│  │                                                                   │
│  ├─ SharedAppleImagesController                                     │
│  │  ├─ CRUD operations                                              │
│  │  ├─ Filters: system_images, branding_images, template_images    │
│  │  └─ Uses: SharedAppleImage model                                 │
│  │                                                                   │
│  ├─ AppleAmbImagesController (inbox-specific)                       │
│  │  └─ Uses: AppleListPickerImage model                            │
│  │                                                                   │
│  ├─ AppleListPickerImagesController (deprecated)                    │
│  │  └─ Replaced by: AppleAmbImagesController                       │
│  │                                                                   │
│  ├─ AppleConstructPayloadController                                 │
│  │  ├─ POST /validate                                               │
│  │  │  └─ Uses: ConstructPayloadValidator                          │
│  │  └─ POST /send                                                   │
│  │     └─ Uses: SendCustomPayloadService                           │
│  │                                                                   │
│  ├─ AppleMessagesController                                         │
│  │  └─ GET /apple_messages (list channels)                         │
│  │                                                                   │
│  └─ Webhooks::AppleMessagesForBusinessController                    │
│     ├─ POST /webhooks/apple_messages_for_business                  │
│     ├─ Validates: JWT token (JwtService)                           │
│     └─ Routes to: MessageProcessorService                           │
│                                                                      │
└──────────────────────────┬────────────────────────────────────────────┘
                           ↓
┌───────────────────────────────────────────────────────────────────────┐
│                      SERVICE LAYER                                     │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Core Services                                                        │
│  ├─ SendMessageService (base class)                                 │
│  │  ├─ Uses: CaseTransformer                                        │
│  │  ├─ Uses: ImageFetchService                                      │
│  │  ├─ Uses: ConstructPayloadService                                │
│  │  └─ Children:                                                     │
│  │     ├─ SendListPickerService                                     │
│  │     ├─ SendTimePickerService                                     │
│  │     ├─ FormService                                               │
│  │     ├─ SendQuickReplyService                                     │
│  │     ├─ SendRichLinkService                                       │
│  │     ├─ SendAuthenticationService                                 │
│  │     ├─ SendApplePayService                                       │
│  │     └─ SendCustomPayloadService                                  │
│  │                                                                   │
│  ├─ IncomingMessageService                                          │
│  │  ├─ Creates: Message records                                     │
│  │  ├─ Updates: Conversation records                                │
│  │  └─ Triggers: EventListener                                      │
│  │                                                                   │
│  ├─ MessageProcessorService                                         │
│  │  ├─ Parses: Apple MSP webhook payload                           │
│  │  └─ Routes to: IncomingMessageService                           │
│  │                                                                   │
│  ├─ CaseTransformer                                                  │
│  │  ├─ to_apple_format (snake_case → camelCase)                    │
│  │  └─ from_apple_format (camelCase → snake_case)                  │
│  │                                                                   │
│  ├─ TemplateFacade                                                   │
│  │  ├─ load_data(block_type)                                       │
│  │  ├─ load_data_with_images(block_type)                           │
│  │  │  └─ Uses: ImageFetchService                                  │
│  │  ├─ save_data(block_type, properties)                           │
│  │  └─ Routes to:                                                   │
│  │     ├─ MetadataStrategy (≤2 blocks)                             │
│  │     └─ ContentBlocksStrategy (>2 blocks)                        │
│  │                                                                   │
│  └─ ImageFetchService                                               │
│     ├─ Three-tier fallback:                                         │
│     │  1. AppleListPickerImage (inbox-specific)                    │
│     │  2. SharedAppleImage (account-wide)                          │
│     │  3. Embedded images (content_attributes['images'])           │
│     └─ Returns: base64-encoded images                               │
│                                                                      │
│  Integration Services                                                │
│  ├─ ApplePayService                                                  │
│  │  ├─ Uses: MerchantSessionService                                │
│  │  ├─ Uses: PaymentGatewayService                                 │
│  │  └─ Supports: Stripe, Square, Braintree                         │
│  │                                                                   │
│  ├─ OAuth2Service                                                    │
│  │  ├─ Uses: AuthenticationService                                 │
│  │  ├─ Uses: LandingPageService                                    │
│  │  └─ Supports: Google, Apple, Custom                             │
│  │                                                                   │
│  ├─ AppleMapsService                                                 │
│  │  ├─ Store locator                                                │
│  │  ├─ Geocoding                                                    │
│  │  └─ Rich link generation                                         │
│  │                                                                   │
│  ├─ OpenGraphParserService                                          │
│  │  ├─ Uses: HTTParty                                               │
│  │  ├─ Fetches: URL metadata                                        │
│  │  └─ Extracts: Favicons                                           │
│  │                                                                   │
│  └─ AcousticHouseBotService                                         │
│     ├─ 780+ lines                                                    │
│     ├─ 45+ state handlers                                            │
│     ├─ Uses: TemplateFacade                                         │
│     ├─ Uses: ImageFetchService                                      │
│     └─ Uses: All Send*Services                                      │
│                                                                      │
│  Utility Services                                                    │
│  ├─ JwtService                                                       │
│  ├─ PayloadValidatorService                                         │
│  ├─ ConstructPayloadValidator                                       │
│  ├─ LogSanitizer                                                     │
│  ├─ TypingIndicatorService                                          │
│  ├─ KeyPairService                                                   │
│  └─ AttachmentCipherService                                         │
│                                                                      │
└──────────────────────────┬────────────────────────────────────────────┘
                           ↓
┌───────────────────────────────────────────────────────────────────────┐
│                      DATABASE LAYER                                    │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Models & Tables                                                      │
│  ├─ Channel::AppleMessagesForBusiness                               │
│  │  ├─ Table: channel_apple_messages_for_business                  │
│  │  ├─ JSONB columns:                                               │
│  │  │  ├─ provider_config                                           │
│  │  │  ├─ oauth2_providers                                          │
│  │  │  ├─ payment_settings                                          │
│  │  │  ├─ payment_processors                                        │
│  │  │  ├─ auth_sessions                                             │
│  │  │  └─ imessage_apps                                             │
│  │  └─ Associations:                                                 │
│  │     ├─ belongs_to :account                                       │
│  │     └─ has_many :inboxes                                         │
│  │                                                                   │
│  ├─ Message                                                           │
│  │  ├─ content_type: string (apple_list_picker, etc.)              │
│  │  ├─ content_attributes: jsonb (snake_case)                      │
│  │  ├─ apple_msp_payload: jsonb (debug)                            │
│  │  └─ Associations:                                                 │
│  │     ├─ belongs_to :conversation                                  │
│  │     └─ belongs_to :account                                       │
│  │                                                                   │
│  ├─ Conversation                                                      │
│  │  ├─ custom_attributes: jsonb                                     │
│  │  │  └─ bot_enabled, bot_state, etc.                             │
│  │  └─ Associations:                                                 │
│  │     ├─ belongs_to :inbox                                         │
│  │     └─ has_many :messages                                        │
│  │                                                                   │
│  ├─ SharedAppleImage (account-wide)                                 │
│  │  ├─ Table: shared_apple_images                                  │
│  │  ├─ Fields:                                                       │
│  │  │  ├─ account_id                                                │
│  │  │  ├─ identifier (snake_case)                                  │
│  │  │  ├─ image_type (system/branding/template)                   │
│  │  │  ├─ description                                               │
│  │  │  └─ metadata (jsonb)                                          │
│  │  ├─ ActiveStorage: has_one_attached :image                      │
│  │  └─ Unique index: (account_id, identifier)                      │
│  │                                                                   │
│  ├─ AppleListPickerImage (inbox-specific)                           │
│  │  ├─ Table: apple_list_picker_images                             │
│  │  ├─ Fields:                                                       │
│  │  │  ├─ account_id                                                │
│  │  │  ├─ inbox_id                                                  │
│  │  │  ├─ identifier (snake_case)                                  │
│  │  │  ├─ description                                               │
│  │  │  └─ shared_override (boolean)                                │
│  │  ├─ ActiveStorage: has_one_attached :image                      │
│  │  └─ Unique index: (inbox_id, identifier)                        │
│  │                                                                   │
│  ├─ AppleAppMetadata                                                 │
│  │  ├─ Table: apple_app_metadata                                   │
│  │  ├─ Fields:                                                       │
│  │  │  ├─ account_id, inbox_id                                      │
│  │  │  ├─ app_id, bid, name, url, version                          │
│  │  │  ├─ enabled, use_live_layout                                 │
│  │  │  ├─ app_data (jsonb)                                          │
│  │  │  └─ images (jsonb)                                            │
│  │  └─ Unique index: (account_id, app_id)                          │
│  │                                                                   │
│  └─ MessageTemplate                                                   │
│     ├─ metadata (jsonb)                                              │
│     │  └─ apple_message_content (for simple templates)             │
│     └─ has_many :content_blocks (for complex templates)             │
│                                                                      │
└──────────────────────────┬────────────────────────────────────────────┘
                           ↓
┌───────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL DEPENDENCIES                               │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Apple Services                                                       │
│  ├─ Apple MSP API                                                    │
│  │  ├─ POST /messages (send messages)                               │
│  │  ├─ Requires: JWT authentication                                 │
│  │  └─ Expects: camelCase payloads                                  │
│  │                                                                   │
│  ├─ Apple Pay                                                         │
│  │  ├─ Merchant session API                                         │
│  │  ├─ Payment processing                                           │
│  │  └─ Requires: Merchant certificates                              │
│  │                                                                   │
│  ├─ Apple Maps API                                                    │
│  │  ├─ Geocoding service                                            │
│  │  ├─ Store locator                                                │
│  │  └─ Requires: API key + Team ID                                  │
│  │                                                                   │
│  └─ Apple Sign In (OAuth2)                                          │
│     └─ Requires: Client ID + Team ID + Private key                  │
│                                                                      │
│  Payment Processors                                                  │
│  ├─ Stripe                                                            │
│  │  ├─ Publishable key + Secret key                                │
│  │  └─ Payment Intent API                                           │
│  │                                                                   │
│  ├─ Square                                                            │
│  │  ├─ Application ID + Access token                               │
│  │  └─ Payments API                                                 │
│  │                                                                   │
│  └─ Braintree                                                         │
│     ├─ Merchant ID + Public/Private keys                           │
│     └─ Transaction API                                              │
│                                                                      │
│  OAuth2 Providers                                                    │
│  ├─ Google OAuth2                                                    │
│  │  ├─ Client ID + Client Secret                                   │
│  │  ├─ Authorization URL                                            │
│  │  └─ Token URL                                                     │
│  │                                                                   │
│  └─ Custom OAuth2                                                     │
│     └─ Configurable endpoints                                       │
│                                                                      │
│  HTTP Services                                                       │
│  └─ HTTParty (for URL fetching)                                     │
│     └─ Used by: OpenGraphParserService                              │
│                                                                      │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Message Flow Dependencies

### Outgoing Message Flow

```
User Action (Agent)
  ↓
Vue Component (e.g., AppleFormBuilder.vue)
  ↓ emits message data (camelCase)
MessagesController
  ↓ normalize_apple_messages_params (before_action)
CaseTransformer.from_apple_format
  ↓ converts to snake_case
ContentAttributeValidator
  ↓ validates structure
Message.create (PostgreSQL JSONB)
  ↓ triggers
SendMessageService (hierarchy)
  ↓ determine service type
TemplateFacade.load_data_with_images (if template)
  ↓ loads template
ImageFetchService.fetch_and_encode
  ↓ three-tier fallback
  │ 1. AppleListPickerImage (inbox)
  │ 2. SharedAppleImage (account)
  │ 3. Embedded images (template)
  ↓ returns base64 images
CaseTransformer.to_apple_format
  ↓ converts to camelCase
ConstructPayloadService.build
  ↓ adds JWT token
PayloadValidatorService.validate
  ↓ validates Apple MSP format
HTTP POST to Apple MSP API
  ↓ Authorization: Bearer JWT
Apple MSP delivers to iPhone
  ↓
User sees message
```

### Incoming Message Flow

```
User sends message (iPhone)
  ↓
Apple MSP API
  ↓ webhook POST
Webhooks::AppleMessagesForBusinessController
  ↓ validates JWT
JwtService.verify_token
  ↓ parses payload
MessageProcessorService
  ↓ extracts data
IncomingMessageService
  ↓ creates/updates
Conversation.find_or_create
Message.create (snake_case in JSONB)
  ↓ triggers
EventListener (ActionCable)
  ↓ broadcasts to frontend
WebSocket → Dashboard
  ↓
Agent sees message (Vue component)
```

---

## Template System Dependencies

```
Template Creation Flow:
  Template Editor (Vue)
    ↓ POST /message_templates
  MessagesController
    ↓ normalize params
  MessageTemplate.create
    ↓ storage decision
  TemplateFacade
    ↓ complexity check
    ├─ Simple (≤2 blocks) → MetadataStrategy
    │   └─ Stores in: metadata['apple_message_content']
    │
    └─ Complex (>2 blocks) → ContentBlocksStrategy
        └─ Creates: ContentBlock records

Template Usage Flow:
  AcousticHouseBotService (or manual send)
    ↓ load template
  TemplateFacade.load_data_with_images
    ↓ determine storage
    ├─ MetadataStrategy.load_data
    │   └─ Reads: metadata['apple_message_content']
    │
    └─ ContentBlocksStrategy.load_data
        └─ Queries: content_blocks table
    ↓ fetch images
  ImageFetchService.fetch_and_encode
    ↓ add images to data
  Returns: complete template data with images
```

---

## Image System Dependencies

```
Image Upload Flow:
  SharedImageSelector.vue
    ↓ user selects/uploads
  POST /shared_apple_images
    ↓
  SharedAppleImagesController
    ↓ params normalization
  SharedAppleImage.create
    ↓ attach file
  ActiveStorage → S3/Local
    ↓
  Returns: { id, identifier, image_type, url }

Image Fetch Flow (Three-Tier):
  ImageFetchService.fetch_and_encode(['messages_png'])
    ↓
  TIER 1: Check inbox-specific
    AppleListPickerImage
      .where(inbox_id: inbox_id, identifier: 'messages_png')
      .includes(image_attachment: :blob)
    ↓ if not found
  TIER 2: Check account-wide shared
    SharedAppleImage
      .where(account_id: account_id, identifier: 'messages_png')
      .includes(image_attachment: :blob)
    ↓ if not found
  TIER 3: Check embedded
    content_attributes['images']
      .find { |img| img['identifier'] == 'messages_png' }
    ↓
  Returns: { identifier, data (base64), description, source }
```

---

## Bot Service Dependencies

```
AcousticHouseBotService Flow:
  Incoming user message
    ↓
  IncomingMessageService
    ↓ checks bot_enabled
  Conversation.custom_attributes['bot_enabled'] == true
    ↓ triggers
  AcousticHouseBotService.handle_message
    ↓ determines state
  Conversation.custom_attributes['bot_state']
    ↓ selects template
  TemplateFacade.load_data_with_images('list_picker')
    ↓ fetches images
  ImageFetchService (three-tier)
    ↓ builds payload
  CaseTransformer.to_apple_format
    ↓ sends via
  SendListPickerService.perform
    ↓ updates state
  Conversation.update(custom_attributes: { bot_state: 'next_state' })
```

---

## Validation Chain

```
Message Creation Validation:
  Frontend (Vue)
    ↓ client-side validation
  MessagesController
    ↓ before_action normalization
  CaseTransformer.from_apple_format
    ↓ model validation
  ContentAttributeValidator
    ├─ Validates: required fields
    ├─ Validates: field types
    ├─ Validates: nested structures
    └─ Validates: image format
    ↓ if valid
  Message.create!
    ↓ service validation
  PayloadValidatorService
    ├─ Validates: Apple MSP format
    ├─ Validates: JWT token
    └─ Validates: interactive data
    ↓ if valid
  ConstructPayloadService.build
    ↓ final check
  Send to Apple MSP API
```

---

## Cross-Cutting Concerns

### CaseTransformer Usage

**Used by**:
- MessagesController (API normalization)
- SendMessageService (base class)
- SendListPickerService
- SendTimePickerService
- FormService
- SendQuickReplyService
- All Send*Services

**NOT used by**:
- ImageFetchService (operates on snake_case identifiers)
- Database models (store snake_case)
- TemplateFacade (internal snake_case)

### LogSanitizer Usage

**Used by**:
- All Send*Services (before logging payloads)
- MessageProcessorService (incoming data)
- OAuth2Service (auth tokens)
- ApplePayService (payment data)

### ImageFetchService Usage

**Used by**:
- TemplateFacade (load_data_with_images)
- SendListPickerService
- SendTimePickerService
- FormService
- AcousticHouseBotService

---

## Environment Variable Dependencies

```
Apple MSP:
  APPLE_MSP_API_URL
    └─ Used by: ConstructPayloadService, SendMessageService

Webhooks:
  FRONTEND_URL
    └─ Used by: Channel setup, webhook URL generation

Apple Pay:
  APPLE_PAY_MERCHANT_ID
  APPLE_PAY_MERCHANT_CERT_PATH
    └─ Used by: ApplePayService, MerchantSessionService

Apple Maps:
  APPLE_MAPS_API_KEY
  APPLE_MAPS_TEAM_ID
    └─ Used by: AppleMapsService

Payment Processors:
  STRIPE_PUBLISHABLE_KEY, STRIPE_SECRET_KEY
  SQUARE_APPLICATION_ID, SQUARE_ACCESS_TOKEN
  BRAINTREE_MERCHANT_ID, BRAINTREE_PUBLIC_KEY, BRAINTREE_PRIVATE_KEY
    └─ Used by: PaymentGatewayService

ActiveStorage:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_BUCKET
    OR
  STORAGE_DRIVER=local
    └─ Used by: All image uploads
```

---

## Critical Path Analysis

### Most Critical Components (High Impact)

**If these fail, entire system breaks**:
1. **CaseTransformer** - All messages fail without case conversion
2. **SendMessageService** - No outgoing messages possible
3. **MessageProcessorService** - No incoming messages processed
4. **JwtService** - Authentication fails, webhooks rejected
5. **Channel::AppleMessagesForBusiness** model - Configuration unavailable

### High Impact Components

**If these fail, major features break**:
1. **ImageFetchService** - Images fail to load (messages work without images)
2. **TemplateFacade** - Template-based messages fail
3. **ContentAttributeValidator** - Invalid messages created (caught by Apple MSP)
4. **ConstructPayloadService** - Malformed payloads sent

### Medium Impact Components

**If these fail, specific features break**:
1. **ApplePayService** - Only Apple Pay breaks
2. **OAuth2Service** - Only authentication messages break
3. **AppleMapsService** - Only maps integration breaks
4. **AcousticHouseBotService** - Only bot breaks

### Low Impact Components

**If these fail, minor features break**:
1. **LogSanitizer** - Logs may contain PII (privacy issue, not functionality)
2. **PayloadValidatorService** - Invalid payloads sent (caught by Apple MSP)
3. **TypingIndicatorService** - Typing indicators don't work

---

## Testing Dependencies

```
Backend Testing Stack:
  RSpec
    ↓ uses
  FactoryBot
    ├─ channel_apple_messages_for_business factory
    ├─ apple_list_picker_image factory
    ├─ shared_apple_image factory
    └─ message factory
    ↓ tests
  Service specs (40+ specs)
  Model specs (5+ specs)
  Controller specs (7+ specs)
  Integration specs (10+ specs)

Frontend Testing Stack:
  Vitest (unit tests)
    ↓ tests
  Vue components (25+ components)
    ↓ uses
  Testing Library (component testing)
    ↓
  Integration tests (message flow)

E2E Testing Stack:
  Cypress
    ↓ tests
  Full user flows
    ├─ Send list picker
    ├─ Send time picker
    ├─ Send form
    └─ Receive interactive response
```

---

**Document Generated**: 2025-11-28
**Companion to**: AMB_INTEGRATION_STATUS_REPORT.md

Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
