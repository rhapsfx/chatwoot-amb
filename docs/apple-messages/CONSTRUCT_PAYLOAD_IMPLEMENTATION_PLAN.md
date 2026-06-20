# Construct Payload API - Complete Implementation Plan

**Status**: ❌ NOT IMPLEMENTED
**Priority**: HIGH - Required for Apple MSP Certification
**Date**: 2025-01-27

---

## Executive Summary

The **Construct Payload API** is a required Apple MSP feature for generating **App Clips Rich Links**. This feature is currently **missing** from the codebase despite being marked as "complete" in the MSP checklist.

**What is Construct Payload?**
- Calls Apple MSP Gateway: `POST https://mspgw.push.apple.com/v1/constructPayload`
- Takes a URL and generates an App Clips RichLink payload
- Returns `richLinkDataRef` (reference to App Clips content on Apple's servers)
- Enables instant app experiences without installation

**Reference Documentation**: `_apple/msp-rest-api/src/docs/construct-payload.md`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Vue 3)                         │
│  ┌────────────────────────────────────────────────────┐    │
│  │ EnhancedRichLinkModal.vue                          │    │
│  │  - Mode: Manual vs App Clips                       │    │
│  │  - Store Region Selector                           │    │
│  │  - Generate Button                                 │    │
│  └────────────────┬───────────────────────────────────┘    │
│                   │                                         │
│  ┌────────────────▼───────────────────────────────────┐    │
│  │ useAppClips.js (Composable)                        │    │
│  │  - State: isGenerating, error, richLinkDataRef     │    │
│  │  - Method: generateAppClips()                      │    │
│  └────────────────┬───────────────────────────────────┘    │
│                   │                                         │
│  ┌────────────────▼───────────────────────────────────┐    │
│  │ constructPayload.js (API Client)                   │    │
│  │  - POST /construct_payload                         │    │
│  └────────────────┬───────────────────────────────────┘    │
└───────────────────┼─────────────────────────────────────────┘
                    │ HTTPS (camelCase JSON)
┌───────────────────▼─────────────────────────────────────────┐
│                 Backend (Rails)                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ AppleConstructPayloadController                      │  │
│  │  - before_action: normalize params (camelCase→snake) │  │
│  │  - Validate request                                  │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                         │
│  ┌────────────────▼─────────────────────────────────────┐  │
│  │ ConstructPayloadValidator                            │  │
│  │  - URL format (HTTPS required)                       │  │
│  │  - Store region (ISO 3166 alpha-2)                   │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                         │
│  ┌────────────────▼─────────────────────────────────────┐  │
│  │ ConstructPayloadService                              │  │
│  │  - Call Apple MSP Gateway                            │  │
│  │  - JWT authentication                                │  │
│  │  - Parse richLinkDataRef                             │  │
│  └────────────────┬─────────────────────────────────────┘  │
│                   │                                         │
│  ┌────────────────▼─────────────────────────────────────┐  │
│  │ CaseTransformer.to_apple_format()                    │  │
│  │  - Convert snake_case → camelCase                    │  │
│  └────────────────┬─────────────────────────────────────┘  │
└───────────────────┼─────────────────────────────────────────┘
                    │ HTTPS (camelCase JSON)
┌───────────────────▼─────────────────────────────────────────┐
│           Apple MSP Gateway                                 │
│  POST /v1/constructPayload                                 │
│  Returns: richLinkDataRef                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Critical Implementation Notes

### 🚨 MANDATORY: CaseTransformer Usage

**ALL Apple MSP API calls MUST use CaseTransformer**

```ruby
# ✅ CORRECT - Use CaseTransformer
payload = {
  'type' => 'link',
  'link' => {
    'url' => url,
    'store_region' => store_region
  },
  'version' => 1.0
}

# Transform to camelCase for Apple MSP
apple_payload = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payload)
# Result: { "type" => "link", "link" => { "url" => "...", "storeRegion" => "US" }, "version" => 1.0 }
```

**Key Mappings**:
- `store_region` → `storeRegion`
- `rich_link_data_ref` → `richLinkDataRef`
- `signature_base64` → `signature-base64` (special case with hyphen)

### 🚨 Request/Response Format

**Request to Apple MSP** (camelCase):
```json
{
  "type": "link",
  "link": {
    "url": "https://example.com/product",
    "storeRegion": "US"
  },
  "version": 1.0
}
```

**Response from Apple MSP** (camelCase):
```json
{
  "version": "1.0",
  "richLinkDataRef": {
    "title": "Product Name",
    "signature-base64": "AZ60f1Fh...",
    "size": 351298,
    "url": "https://p97-content.icloud.com/...",
    "owner": "M66169d55-aaee-48dd-b781-...",
    "key": "00ccec31f00f05d3416bf0a41f47..."
  }
}
```

**Storage in Database** (snake_case):
```ruby
content_attributes: {
  'url' => 'https://example.com/product',
  'rich_link_data_ref' => {
    'title' => 'Product Name',
    'signature_base64' => 'AZ60f1Fh...',  # Note: underscore, not hyphen
    'size' => 351298,
    'url' => 'https://p97-content.icloud.com/...',
    'owner' => 'M66169d55-aaee-48dd-b781-...',
    'key' => '00ccec31f00f05d3416bf0a41f47...'
  }
}
```

### 🚨 Common Pitfalls to Avoid

1. **❌ DON'T use manual case conversion**
   ```ruby
   # WRONG
   payload[:storeRegion] = store_region
   ```
   ```ruby
   # CORRECT
   payload = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payload)
   ```

2. **❌ DON'T store camelCase in database**
   ```ruby
   # WRONG - storing Apple's response directly
   content_attributes['richLinkDataRef'] = apple_response['richLinkDataRef']
   ```
   ```ruby
   # CORRECT - convert to snake_case first
   content_attributes['rich_link_data_ref'] =
     AppleMessagesForBusiness::CaseTransformer.from_apple_format(apple_response['richLinkDataRef'])
   ```

3. **❌ DON'T forget to handle signature-base64 → signature_base64**
   ```ruby
   # The special case: hyphen in API, underscore in database
   # CaseTransformer handles this automatically
   ```

4. **❌ DON'T skip JWT authentication**
   ```ruby
   # REQUIRED headers for Apple MSP
   headers = {
     'Authorization' => "Bearer #{channel.generate_jwt_token}",
     'Content-Type' => 'application/json',
     'id' => SecureRandom.uuid,
     'Source-Id' => channel.business_id
   }
   ```

---

## Implementation Phases

### Phase 1: Backend Service Layer

#### File 1: `ConstructPayloadService`
**Path**: `app/services/apple_messages_for_business/construct_payload_service.rb`

```ruby
# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  AMB_SERVER = 'https://mspgw.push.apple.com/v1'

  def initialize(channel:, url:, store_region: 'US')
    @channel = channel
    @url = url
    @store_region = store_region
  end

  def perform
    # Validate inputs
    validator = AppleMessagesForBusiness::ConstructPayloadValidator.new(
      url: @url,
      store_region: @store_region
    )

    unless validator.valid?
      return {
        success: false,
        error: validator.errors.full_messages.join(', '),
        error_code: 'VALIDATION_FAILED'
      }
    end

    # Build request payload (snake_case internally)
    payload = build_request_payload

    # Transform to Apple format (camelCase)
    apple_payload = AppleMessagesForBusiness::CaseTransformer.to_apple_format(payload)

    log_info "🔍 Construct Payload - Request: #{apple_payload.to_json}"

    # Call Apple MSP Gateway
    response = call_apple_construct_payload(apple_payload)

    if response.success?
      # Parse response and convert from camelCase to snake_case
      result = JSON.parse(response.body)

      log_info "✅ Construct Payload - Success: #{result.keys}"

      # Convert richLinkDataRef from camelCase to snake_case for storage
      rich_link_data_ref = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
        result['richLinkDataRef']
      )

      {
        success: true,
        rich_link_data_ref: rich_link_data_ref,
        version: result['version']
      }
    else
      error_message = response.code == 400 ? 'URL does not support App Clips' : "HTTP #{response.code}: #{response.body}"
      log_error "❌ Construct Payload - Error: #{error_message}"

      {
        success: false,
        error: error_message,
        error_code: response.code == 400 ? 'NO_APP_CLIPS_SUPPORT' : 'API_ERROR'
      }
    end
  rescue StandardError => e
    log_error "❌ Construct Payload - Exception: #{e.message}"
    {
      success: false,
      error: e.message,
      error_code: 'EXCEPTION'
    }
  end

  private

  def build_request_payload
    {
      'type' => 'link',
      'link' => {
        'url' => @url,
        'store_region' => @store_region
      },
      'version' => 1.0
    }
  end

  def call_apple_construct_payload(payload)
    message_id = SecureRandom.uuid

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => @channel.business_id
    }

    HTTParty.post(
      "#{AMB_SERVER}/constructPayload",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end
end
```

#### File 2: `ConstructPayloadValidator`
**Path**: `app/services/apple_messages_for_business/construct_payload_validator.rb`

```ruby
# frozen_string_literal: true

class AppleMessagesForBusiness::ConstructPayloadValidator
  include ActiveModel::Validations

  attr_accessor :url, :store_region

  # ISO 3166 alpha-2 country codes
  VALID_STORE_REGIONS = %w[
    US GB CA AU DE FR JP CN IN BR
    IT ES NL SE CH BE AT NO DK FI
    IE PT PL CZ HU GR RO SK BG HR
    LT LV EE SI CY MT LU
  ].freeze

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]) }
  validates :store_region, presence: true, inclusion: { in: VALID_STORE_REGIONS }

  def initialize(url:, store_region:)
    @url = url
    @store_region = store_region&.upcase
  end
end
```

---

### Phase 2: API Controller & Routes

#### File 3: `AppleConstructPayloadController`
**Path**: `app/controllers/api/v1/accounts/inboxes/apple_construct_payload_controller.rb`

```ruby
# frozen_string_literal: true

class Api::V1::Accounts::Inboxes::AppleConstructPayloadController < Api::V1::Accounts::BaseController
  before_action :set_inbox
  before_action :validate_apple_messages_inbox

  # POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_construct_payload
  def create
    url = construct_payload_params[:url]
    store_region = construct_payload_params[:store_region] || 'US'

    service = AppleMessagesForBusiness::ConstructPayloadService.new(
      channel: @inbox.channel,
      url: url,
      store_region: store_region
    )

    result = service.perform

    if result[:success]
      render json: {
        success: true,
        rich_link_data_ref: result[:rich_link_data_ref],
        version: result[:version]
      }, status: :ok
    else
      render json: {
        success: false,
        error: result[:error],
        error_code: result[:error_code]
      }, status: result[:error_code] == 'NO_APP_CLIPS_SUPPORT' ? :bad_request : :unprocessable_entity
    end
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def validate_apple_messages_inbox
    unless @inbox.channel_type == 'Channel::AppleMessagesForBusiness'
      render json: { error: 'Inbox must be an Apple Messages for Business channel' }, status: :unprocessable_entity
    end
  end

  def construct_payload_params
    # API controller auto-normalizes camelCase → snake_case via before_action
    params.require(:construct_payload).permit(:url, :store_region)
  end
end
```

#### File 4: Routes Configuration
**Path**: `config/routes.rb` (modify)

```ruby
# Add inside the accounts namespace, around line 165
resources :apple_messages, only: [] do
  collection do
    post :construct_payload
  end
end
```

**Endpoint**: `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_messages/construct_payload`

---

### Phase 3: Integration with SendRichLinkService

#### File 5: Modify `SendRichLinkService`
**Path**: `app/services/apple_messages_for_business/send_rich_link_service.rb` (modify)

**Add method** (around line 92):

```ruby
def build_rich_link_data
  content_attrs = @message.content_attributes

  # NEW: Check if richLinkDataRef exists (from Construct Payload / App Clips)
  if content_attrs['rich_link_data_ref'].present?
    log_info "🔍 Rich Link - Using richLinkDataRef (App Clips mode)"
    return build_from_rich_link_data_ref(content_attrs)
  end

  # EXISTING: Build manual richLinkData with assets
  url = content_attrs['url'] || @message.content

  # ... rest of existing code ...
end

# NEW METHOD
def build_from_rich_link_data_ref(content_attrs)
  # richLinkDataRef is stored in snake_case in database
  # Convert to camelCase for Apple MSP
  rich_link_data_ref = content_attrs['rich_link_data_ref']

  # Transform to Apple format
  apple_format_ref = AppleMessagesForBusiness::CaseTransformer.to_apple_format(rich_link_data_ref)

  log_info "🔍 Rich Link - richLinkDataRef keys: #{apple_format_ref.keys}"

  {
    url: content_attrs['url'],
    richLinkDataRef: apple_format_ref
  }
end
```

**Modify payload construction** (around line 35):

```ruby
rich_link_data = build_rich_link_data

payload = {
  id: message_id,
  type: 'richLink',
  sourceId: @channel.business_id,
  destinationId: @destination_id,
  v: 1,
  body: rich_link_data[:url]
}

# Add either richLinkData OR richLinkDataRef (not both)
if rich_link_data[:richLinkDataRef].present?
  payload[:richLinkDataRef] = rich_link_data[:richLinkDataRef]
else
  payload[:richLinkData] = rich_link_data
end
```

---

### Phase 4: Content Attribute Validator

#### File 6: Modify ContentAttributeValidator
**Path**: `app/models/concerns/content_attribute_validator.rb` (modify)

```ruby
ALLOWED_APPLE_RICH_LINK_KEYS = [
  :url, :title, :image_url, :image_data, :image_mime_type,
  :video_url, :video_mime_type, :favicon_url, :description,
  :rich_link_data_ref  # NEW: Add support for richLinkDataRef (App Clips)
].freeze
```

---

### Phase 5: Vue Frontend Implementation

#### File 7: API Client
**Path**: `app/javascript/dashboard/api/appleMessages/constructPayload.js`

```javascript
import ApiClient from '../ApiClient';

class ConstructPayloadAPI extends ApiClient {
  constructor() {
    super('apple_messages', { accountScoped: true });
  }

  async create(accountId, inboxId, payload) {
    try {
      const response = await this.axios.post(
        `${this.url}/${accountId}/inboxes/${inboxId}/apple_messages/construct_payload`,
        {
          construct_payload: {
            url: payload.url,
            store_region: payload.storeRegion || 'US',
          },
        }
      );
      return response.data;
    } catch (error) {
      if (error.response?.status === 400) {
        return {
          success: false,
          error: 'This URL does not support App Clips',
          error_code: 'NO_APP_CLIPS_SUPPORT',
        };
      }
      throw error;
    }
  }

  mightSupportAppClips(url) {
    try {
      const urlObj = new URL(url);
      return urlObj.protocol === 'https:' && urlObj.hostname.includes('.');
    } catch {
      return false;
    }
  }
}

export default new ConstructPayloadAPI();
```

#### File 8: Composable
**Path**: `app/javascript/dashboard/composables/useAppClips.js`

```javascript
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import constructPayloadAPI from 'dashboard/api/appleMessages/constructPayload';

export function useAppClips(inboxId) {
  const store = useStore();

  const isGenerating = ref(false);
  const appClipsError = ref(null);
  const richLinkDataRef = ref(null);
  const selectedStoreRegion = ref('US');

  const accountId = computed(() => store.getters.getCurrentAccountId);

  const storeRegions = [
    { code: 'US', name: 'United States' },
    { code: 'GB', name: 'United Kingdom' },
    { code: 'CA', name: 'Canada' },
    { code: 'AU', name: 'Australia' },
    { code: 'DE', name: 'Germany' },
    { code: 'FR', name: 'France' },
    { code: 'JP', name: 'Japan' },
    { code: 'CN', name: 'China' },
    { code: 'IN', name: 'India' },
    { code: 'BR', name: 'Brazil' },
  ];

  const generateAppClips = async (url) => {
    if (!url) {
      appClipsError.value = 'Please enter a URL';
      return { success: false };
    }

    if (!constructPayloadAPI.mightSupportAppClips(url)) {
      appClipsError.value = 'URL must be HTTPS and have a valid domain';
      return { success: false };
    }

    isGenerating.value = true;
    appClipsError.value = null;
    richLinkDataRef.value = null;

    try {
      const result = await constructPayloadAPI.create(
        accountId.value,
        inboxId.value,
        {
          url,
          storeRegion: selectedStoreRegion.value,
        }
      );

      if (result.success) {
        richLinkDataRef.value = result.rich_link_data_ref;
        return {
          success: true,
          richLinkDataRef: result.rich_link_data_ref
        };
      } else {
        appClipsError.value = result.error || 'Failed to generate App Clips';
        return { success: false, error: result.error };
      }
    } catch (error) {
      console.error('App Clips generation error:', error);
      appClipsError.value = error.message || 'Network error';
      return { success: false, error: error.message };
    } finally {
      isGenerating.value = false;
    }
  };

  const clearError = () => {
    appClipsError.value = null;
  };

  const reset = () => {
    isGenerating.value = false;
    appClipsError.value = null;
    richLinkDataRef.value = null;
    selectedStoreRegion.value = 'US';
  };

  return {
    isGenerating,
    appClipsError,
    richLinkDataRef,
    selectedStoreRegion,
    storeRegions,
    generateAppClips,
    clearError,
    reset,
  };
}
```

#### File 9: Enhanced Rich Link Modal
**Path**: `app/javascript/dashboard/components-next/message/modals/EnhancedRichLinkModal.vue`

**Full component code in separate file** (see Phase 5 Frontend section in previous response)

---

### Phase 6: Testing

#### File 10: Service Spec
**Path**: `spec/services/apple_messages_for_business/construct_payload_service_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConstructPayloadService do
  let(:channel) { create(:channel_apple_messages_for_business) }
  let(:url) { 'https://example.com/product' }
  let(:store_region) { 'US' }
  let(:service) { described_class.new(channel: channel, url: url, store_region: store_region) }

  describe '#perform' do
    context 'with valid App Clips URL' do
      let(:apple_response) do
        {
          'version' => '1.0',
          'richLinkDataRef' => {
            'title' => 'Product Name',
            'signature-base64' => 'AZ60f1Fh...',
            'size' => 351298,
            'url' => 'https://p97-content.icloud.com/...',
            'owner' => 'M66169d55-aaee-48dd-b781-...',
            'key' => '00ccec31f00f05d3416bf0a41f47...'
          }
        }
      end

      before do
        stub_request(:post, 'https://mspgw.push.apple.com/v1/constructPayload')
          .to_return(status: 200, body: apple_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success with richLinkDataRef' do
        result = service.perform

        expect(result[:success]).to be true
        expect(result[:rich_link_data_ref]).to be_present
        expect(result[:rich_link_data_ref]['title']).to eq('Product Name')
        # Verify snake_case conversion
        expect(result[:rich_link_data_ref]['signature_base64']).to be_present
        expect(result[:rich_link_data_ref]['signature-base64']).to be_nil
      end
    end

    context 'with non-App Clips URL' do
      before do
        stub_request(:post, 'https://mspgw.push.apple.com/v1/constructPayload')
          .to_return(status: 400, body: 'Bad Request')
      end

      it 'returns error with NO_APP_CLIPS_SUPPORT code' do
        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include('does not support App Clips')
        expect(result[:error_code]).to eq('NO_APP_CLIPS_SUPPORT')
      end
    end

    context 'with invalid store region' do
      let(:store_region) { 'INVALID' }

      it 'returns validation error' do
        result = service.perform

        expect(result[:success]).to be false
        expect(result[:error_code]).to eq('VALIDATION_FAILED')
      end
    end
  end
end
```

---

## Implementation Checklist

### Backend ✅
- [ ] Create `ConstructPayloadService` with CaseTransformer integration
- [ ] Create `ConstructPayloadValidator` with ISO 3166 validation
- [ ] Create `AppleConstructPayloadController`
- [ ] Add routes configuration
- [ ] Modify `SendRichLinkService` to support `richLinkDataRef`
- [ ] Update `ContentAttributeValidator` with `rich_link_data_ref` key
- [ ] Add RSpec tests for service and controller

### Frontend ✅
- [ ] Create `constructPayload.js` API client
- [ ] Create `useAppClips.js` composable
- [ ] Create `EnhancedRichLinkModal.vue` component
- [ ] Integrate into `AppleMessagesComposer.vue`
- [ ] Add i18n translations (English)
- [ ] Add component tests (Vitest)

### Integration ✅
- [ ] Test backend API with curl/Postman
- [ ] Test frontend UI in browser
- [ ] Test end-to-end flow (UI → API → Apple MSP)
- [ ] Verify CaseTransformer conversions
- [ ] Test error handling (400 errors)

### Documentation ✅
- [ ] Update CLAUDE.md with Construct Payload usage
- [ ] Create API documentation
- [ ] Update MSP checklist to "IMPLEMENTED"

---

## Testing Strategy

### Manual Testing Steps

1. **Backend API Test**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/accounts/1/inboxes/1/apple_messages/construct_payload \
     -H "Content-Type: application/json" \
     -d '{"construct_payload": {"url": "https://example.com", "store_region": "US"}}'
   ```

2. **Frontend UI Test**:
   - Open AppleMessagesComposer
   - Click "Create Rich Link"
   - Toggle to "App Clips" mode
   - Enter URL: `https://example.com/product`
   - Select Store Region: "United States"
   - Click "Generate App Clips"
   - Verify success/error message
   - Click "Send Rich Link"
   - Verify message sent with `richLinkDataRef`

3. **End-to-End Test**:
   - Send App Clips rich link to test customer
   - Verify message displays correctly on iOS device
   - Verify App Clips launches when tapped

---

## Deployment

### Production Deployment Steps

1. **Run migrations** (if any database changes)
2. **Deploy backend**: `./script/deploy-production-docker.sh`
3. **Build frontend assets**: `bin/vite build`
4. **Restart servers**
5. **Verify in production**:
   - Test Construct Payload API endpoint
   - Test sending App Clips rich link
   - Monitor logs for errors

---

## Success Criteria

✅ **Functional**:
- [ ] Backend API calls Apple MSP `/constructPayload` successfully
- [ ] CaseTransformer handles all snake_case ↔ camelCase conversions
- [ ] Frontend UI allows toggling between Manual and App Clips modes
- [ ] Error handling covers 400 errors (No App Clips support)
- [ ] SendRichLinkService sends messages with `richLinkDataRef`

✅ **Quality**:
- [ ] RSpec tests achieve >80% coverage
- [ ] No linting errors in Vue components
- [ ] No Rubocop violations in Ruby code
- [ ] Logging provides clear debugging information

✅ **Documentation**:
- [ ] CLAUDE.md updated with usage instructions
- [ ] API documentation complete
- [ ] MSP checklist updated

---

## Related Documentation

- **Apple MSP Docs**: `_apple/msp-rest-api/src/docs/construct-payload.md`
- **RichLink Spec**: `_apple/msp-rest-api/src/docs/type-richlink.md`
- **CaseTransformer**: `docs/apple-messages/case-normalization-specification.md`
- **MSP Checklist**: `docs/apple-messages/reports/APPLE_MSP_MISSING_FEATURES_CHECKLIST.md`

---

## Agent Delegation Plan

**Agent 1**: Backend Developer - Create services and controller
**Agent 2**: Vue Frontend Specialist - Create Vue components and composable
**Agent 3**: Integration Specialist - Modify SendRichLinkService and test flow
**Agent 4**: QA Engineer - Write and run tests
