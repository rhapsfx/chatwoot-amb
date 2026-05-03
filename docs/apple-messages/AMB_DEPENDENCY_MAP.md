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
│  ├─ Message Composition (3 components) ⭐ CRITICAL FOR "/" CMD     │
│  │  ├─ ReplyBox.vue                                                 │
│  │  │  ├─ Imports: TemplateSelector.vue                             │
│  │  │  └─ Imports: ReplyBottomPanel.vue                             │
│  │  ├─ ReplyBottomPanel.vue                                         │
│  │  │  ├─ Imports: AppleMessagesButton.vue ⭐ KEY FIX              │
│  │  │  ├─ Emits: sendAppleMessage → ReplyBox                        │
│  │  │  └─ Routes to: Apple Messages Modal                           │
│  │  └─ TemplateSelector.vue ⭐ "/" COMMAND HANDLER                 │
│  │     ├─ Triggered by: "/" in message input                        │
│  │     ├─ Dispatches: messageTemplates/get (store action)           │
│  │     ├─ Filters by: channelType, status='active'                  │
│  │     ├─ Depends on: Vuex messageTemplates module                  │
│  │     └─ Items: Canned responses + Templates                       │
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
│                    VUEX STORE LAYER ⭐ CRITICAL                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  messageTemplates Module (stores/modules/messageTemplates.js)         │
│  ├─ **MUST be registered** in store/index.js (line 41, module list)  │
│  │  └─ Import: import messageTemplates from './modules/messageTemplates'
│  │                                                                    │
│  ├─ State:                                                            │
│  │  ├─ records: [] (template array)                                  │
│  │  ├─ selectedTemplate: null                                        │
│  │  └─ uiFlags: { isFetching, isCreating, isDeleting }              │
│  │                                                                    │
│  ├─ Getters:                                                          │
│  │  ├─ getTemplates → returns records array                          │
│  │  ├─ getUIFlags → returns uiFlags                                  │
│  │  ├─ getTemplate(id) → find by ID                                  │
│  │  └─ getSelectedTemplate → returns selectedTemplate                │
│  │                                                                    │
│  ├─ Actions:                                                          │
│  │  ├─ get({ search='', channel='' }) → fetch from API              │
│  │  │  └─ Calls: TemplatesAPI.get                                    │
│  │  ├─ show(id) → fetch single template                              │
│  │  ├─ create(templateObj) → create new template                     │
│  │  ├─ update(id, templateObj) → update template                     │
│  │  ├─ delete(id) → delete template                                  │
│  │  ├─ render(templateId, parameters, channelType) → preview         │
│  │  └─ createFromAppleMessage(payload) → create from webhook         │
│  │                                                                    │
│  ├─ Mutations ⭐ MUST BE DEFINED IN mutation-types.js:               │
│  │  ├─ SET_TEMPLATE_UI_FLAG (line 139-142)                           │
│  │  ├─ SET_TEMPLATES (line 140-142)                                  │
│  │  ├─ ADD_TEMPLATE (uses MutationHelpers.create)                    │
│  │  ├─ EDIT_TEMPLATE (uses MutationHelpers.update)                   │
│  │  ├─ DELETE_TEMPLATE (uses MutationHelpers.destroy)                │
│  │  └─ SET_SELECTED_TEMPLATE (line 146-148)                          │
│  │                                                                    │
│  └─ Usage by TemplateSelector:                                       │
│     ├─ Getter: this.$store.getters['messageTemplates/getTemplates']  │
│     ├─ Action: this.$store.dispatch('messageTemplates/get', {...})   │
│     └─ Triggers when: "/" typed or search changes                    │
│                                                                        │
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

### "/" Command Template Selector Flow ⭐ CRITICAL

```
Agent types "/" in ReplyBox message input
  ↓ triggers mounted/searchKey watcher
TemplateSelector.vue
  ↓ calls fetchTemplates() method
this.$store.dispatch('messageTemplates/get', { search, channel })
  ↓ commits SET_TEMPLATE_UI_FLAG { isFetching: true }
TemplatesAPI.get({ search, channel })
  ↓ HTTP GET /api/v1/message_templates?search=X&channel=Y
Backend returns: response.data.templates = [...]
  ↓ commits SET_TEMPLATES with template array
Vuex state.records ← [template1, template2, ...]
  ↓ computed getter returns updated records
TemplateSelector.vue re-renders
  ↓ shows filtered items
filteredTemplates → templates filtered by:
  ├─ name.includes(searchKey)
  ├─ description.includes(searchKey)
  ├─ tags include searchKey
  ↓
templateItems → filters by:
  ├─ supported_channels includes channelType
  ├─ status == 'active'
  └─ NOT in use_cases: 'bot_api_only'
  ↓ displays items + canned responses
Agent clicks template item
  ↓ emits 'select' event
ReplyBox handles selection
  ↓ inserts template content into message input
Agent sends message
  ↓ goes through outgoing message flow (above)
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

### Apple Messages Button Flow ⭐ KEY COMPONENT

```
Agent working in ReplyBox (AMB conversation)
  ↓
ReplyBottomPanel.vue (emits from ReplyBox)
  ├─ Imported AppleMessagesButton.vue (CRITICAL FIX)
  └─ Only renders when channel_type == 'Channel::AppleMessagesForBusiness'
  ↓
Agent clicks AppleMessagesButton
  ├─ Button icon: "icon-apple"
  └─ Tooltip: $t('TEMPLATES.APPLE_MESSAGES.BUTTON')
  ↓ emits sendAppleMessage event with { action, payload }
ReplyBox receives sendAppleMessage event
  ↓
ReplyBox opens AppleMessagesComposer modal
  ├─ Props: conversation, inbox, message
  └─ Shows interactive message builder
  ↓
Agent selects/builds interactive message (e.g., list picker)
  ↓
Agent clicks "Send"
  ↓
MessagesController receives message data
  └─ Normal outgoing message flow (from above)

**Why This Component Is Critical**:
- Without AppleMessagesButton, agents cannot access interactive message builders
- It must be registered in ReplyBottomPanel.vue components list
- It must emit 'sendAppleMessage' to parent (ReplyBox)
- It must be conditional on AMB channel type

**Registration Requirement** (app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue):
- Import: import AppleMessagesButton from '../AppleMessagesButton.vue'
- In components: AppleMessagesButton
- In template: <AppleMessagesButton :inbox="inbox" @send-apple-message="$emit('sendAppleMessage', $event)" />
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

### Vuex Mutation Types Registration ⭐ CRITICAL

**File**: `app/javascript/dashboard/store/mutation-types.js`

**Required Definitions for messageTemplates Module**:

```javascript
// Message Templates (MUST be defined for Vuex mutations to work)
SET_TEMPLATE_UI_FLAG: 'SET_TEMPLATE_UI_FLAG',
SET_TEMPLATES: 'SET_TEMPLATES',
ADD_TEMPLATE: 'ADD_TEMPLATE',
EDIT_TEMPLATE: 'EDIT_TEMPLATE',
DELETE_TEMPLATE: 'DELETE_TEMPLATE',
SET_SELECTED_TEMPLATE: 'SET_SELECTED_TEMPLATE',
```

**Why Critical**:

- Without these type definitions, Vuex mutations cannot execute
- TemplateSelector cannot fetch templates without SET_TEMPLATES mutation
- "/" command will show only canned responses, no templates
- Outgoing messages through templates will fail silently

**Module Registration** (`app/javascript/dashboard/store/index.js`):

```javascript
// Line 41: Import the module
import messageTemplates from './modules/messageTemplates';

// Lines 65-126: Register in modules object
modules: {
  // ... other modules
  messageTemplates,
  // ... other modules
}
```

**Without proper registration**:

1. Store module not loaded → getter returns undefined
2. Action dispatch fails → templates not fetched
3. TemplateSelector breaks → "/" command unusable

**Verification**:

```bash
# Check if mutations are defined
grep -n "SET_TEMPLATE" app/javascript/dashboard/store/mutation-types.js

# Check if module is registered
grep -n "messageTemplates" app/javascript/dashboard/store/index.js
```

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

## Phase 6-7 Critical Fixes Summary (May 2026)

### Recently Fixed Issues

These fixes were critical for the v4.12→v4.13.0 upgrade and are documented in commits:

- ceea86655: Display AMB conversation URL on inbox list
- 51d5a12cb: Cleanup debug logging from template selector
- 5497add6d: Complete AMB templates and button support
- 0439c0b64: Register messageTemplates store module
- 3926523c3: Add AppleMessagesButton to ReplyBottomPanel

### 1. ⭐ Missing Vuex Store Module Registration

**Problem**: messageTemplates store module existed but wasn't imported/registered.

**Impact**: "/" command showed only canned responses; no templates appeared.

**Files Changed**:

- `app/javascript/dashboard/store/index.js`: Added import and module registration
- `app/javascript/dashboard/store/mutation-types.js`: Added 6 mutation type definitions

**Verification**:

```bash
grep "import messageTemplates" app/javascript/dashboard/store/index.js
grep "messageTemplates," app/javascript/dashboard/store/index.js
grep "SET_TEMPLATE" app/javascript/dashboard/store/mutation-types.js
```

### 2. ⭐ Missing AppleMessagesButton Integration

**Problem**: AppleMessagesButton component existed but wasn't imported into ReplyBottomPanel.

**Impact**: AMB users couldn't access interactive message composer modal.

**Files Changed**:

- `app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue`: Added import, component registration, event emission

**Verification**:

```bash
grep -A2 "import AppleMessagesButton" app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue
grep "AppleMessagesButton" app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue | grep -c "."
```

### 3. ✅ Missing Mutation Type Definitions

**Problem**: 6 mutation types for messageTemplates were never defined in mutation-types.js.

**Root Cause**: Without type definitions, Vuex couldn't execute mutations even though actions were properly written.

**Files Changed**:

- `app/javascript/dashboard/store/mutation-types.js`: Added SET_TEMPLATE_UI_FLAG, SET_TEMPLATES, ADD_TEMPLATE, EDIT_TEMPLATE, DELETE_TEMPLATE, SET_SELECTED_TEMPLATE

**Impact Chain**:

1. TemplateSelector calls `messageTemplates/get` action
2. Action dispatches `SET_TEMPLATES` mutation
3. Without type definition, mutation fails silently
4. State never updates
5. Getter returns empty array
6. Templates never display

### 4. ✅ Debug Logging Cleanup

**Problem**: Excessive debug logging in TemplateSelector and messageTemplates module.

**Files Changed**:

- `app/javascript/dashboard/components/widgets/conversation/TemplateSelector.vue`: Removed console.log statements
- `app/javascript/dashboard/store/modules/messageTemplates.js`: Removed debug logging

### 5. ✅ AMB Conversation URL Display

**Problem**: "/app/accounts/1/settings/inboxes/list" didn't show full conversation starter URL for AMB inboxes.

**Files Changed**:

- `app/javascript/dashboard/routes/dashboard/settings/inbox/Index.vue`: Added getAMBConversationURL() function and displayed full URL

**Format**: `https://bcrw.apple.com/sms:open?service=iMessage&recipient=urn:biz:{business_id}`

### Recommended Verification Steps

**After pulling latest changes**:

1. Check store module registration:

   ```bash
   grep "import messageTemplates" app/javascript/dashboard/store/index.js
   grep -c "messageTemplates," app/javascript/dashboard/store/index.js
   ```

2. Check mutation types:

   ```bash
   grep "SET_TEMPLATE" app/javascript/dashboard/store/mutation-types.js | wc -l
   # Should return 6
   ```

3. Check AppleMessagesButton integration:

   ```bash
   grep -c "AppleMessagesButton" app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue
   # Should be 3+ (import, component, template)
   ```

4. Check debug logging is removed:

   ```bash
   grep "console.log" app/javascript/dashboard/components/widgets/conversation/TemplateSelector.vue
   grep "console.log" app/javascript/dashboard/store/modules/messageTemplates.js
   # Both should return empty
   ```

5. Test in browser:

   - Open conversation with AMB inbox
   - Type "/" in message input
   - Should see both canned responses AND templates
   - AppleMessagesButton should be visible in reply panel
   - Click AppleMessagesButton → modal should open
   - Visit `/app/accounts/1/settings/inboxes/list` → AMB inboxes should show conversation URL

---

**Document Generated**: 2025-11-28 (Updated May 2, 2026 with Phase 6-7 fixes)
**Companion to**: AMB_INTEGRATION_STATUS_REPORT.md

Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
