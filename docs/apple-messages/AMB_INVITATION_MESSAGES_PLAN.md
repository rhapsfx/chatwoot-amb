# AMB Invitation Messages — Implementation Plan

## Context

Apple has renamed "Business Updates" to **Invitation Messages** — a proactive outbound messaging feature allowing businesses to invite customers to Apple Messages for Business conversations via their phone number. The business sends a template-based notification (Apple-managed templates, not business-defined) to a customer's phone number, and the customer can engage or leave.

This is the AMB equivalent of WhatsApp Template Campaigns: template-driven, opt-in gated, schedulable broadcasts. The implementation must follow existing AMB patterns (CaseTransformer, TemplateFacade, three-tier image fallback) and plug into Chatwoot's existing campaign scheduling infrastructure.

**Key API differences from regular AMB messages:**
- Endpoint: `POST https://mspgw.push.apple.com/v1/message` (same URL, different header)
- Extra required header: `message-type: notification`
- Payload structure: `notification.templateId`, `notification.referenceId`, `notification.locale`, `notification.parameters`
- Templates are Apple-managed (Apple assigns `templateId` to each business)
- CloseSession response (`type: "close"`) = user opted out — must be honored

**Reference doc**: `docs/apple-messages/` → `_apple/msp-rest-api/src/docs/business-updates.md`

---

## UI Placement

| Surface | Purpose |
|---|---|
| **Settings → Campaigns → Apple Messages tab** | Schedule proactive invitation broadcasts to contact segments |
| **Settings → Templates** | Manage invitation template configs (Apple-provided templateId + parameter definitions) using `notification` category |
| **Conversation Composer → Invitation tab** | One-off manual invitation send from inside a conversation thread |
| **Conversation thread** | Render sent invitation as outgoing message bubble + CloseSession as activity |

## Confirmed Design Decisions

| Decision | Choice |
|---|---|
| Message record | ✅ Create `outgoing` message in conversation — agents see it in thread, enables bubble + opt-out status update |
| Campaign targeting | ✅ Dual: **label-based** for production batches + **direct phone number list** for testing/ad-hoc |
| Bot integration | ⏳ Deferred — added in a later phase after core is stable |
| Composer send | ✅ Add "Invitation" tab to `AppleMessagesComposer.vue` for one-off sends from conversation thread |

---

## Architecture

```
Campaign Scheduler (TriggerScheduledItemsJob) [REUSE]
  → Campaigns::TriggerOneoffCampaignJob [REUSE]
  → Campaign#trigger! → case 'AppleMessagesForBusiness' [EXTEND]
  → AppleMessages::OneoffInvitationCampaignService [NEW]
    → check AppleInvitationOptOut [NEW MODEL]
    → SendInvitationService [NEW]
      → Channel::AppleMessagesForBusiness#send_invitation [NEW method]
      → POST mspgw.push.apple.com/v1/message + message-type: notification
      → CaseTransformer.to_apple_format [EXTEND with templateId/referenceId]

Apple MSP → IncomingMessageService [EXTEND]
  → type: "close" → CloseSessionHandlerService [NEW]
    → AppleInvitationOptOut.create [NEW MODEL]
    → Activity message in conversation
```

---

## Phase 1 — Backend Foundation

### 1.1 Database Migration
**File**: `db/migrate/TIMESTAMP_create_apple_invitation_opt_outs.rb`

New table `apple_invitation_opt_outs`:
```ruby
create_table :apple_invitation_opt_outs do |t|
  t.references :account, null: false
  t.references :contact, null: false
  t.string :phone_number, null: false
  t.references :inbox, null: false
  t.datetime :opted_out_at, null: false
  t.jsonb :reference_ids, default: []
  t.timestamps
end
add_index :apple_invitation_opt_outs, [:account_id, :phone_number, :inbox_id], unique: true,
          name: 'idx_apple_inv_opt_outs_unique'
```

### 1.2 Model
**File**: `app/models/apple_invitation_opt_out.rb`

```ruby
class AppleInvitationOptOut < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :inbox

  scope :for_phone, ->(phone) { where(phone_number: phone) }
  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }

  def self.opted_out?(phone_number:, inbox_id:)
    for_phone(phone_number).for_inbox(inbox_id).exists?
  end
end
```

### 1.3 CaseTransformer Extension
**File**: `app/services/apple_messages_for_business/case_transformer.rb`

Add to `TO_APPLE_MAPPINGS`:
```ruby
'template_id'  => 'templateId',
'reference_id' => 'referenceId',
'brand_name'   => 'brandName',
'brand_logo'   => 'brandLogo',
```

### 1.4 SendInvitationService
**File**: `app/services/apple_messages_for_business/send_invitation_service.rb`

```ruby
class AppleMessagesForBusiness::SendInvitationService
  pattr_initialize [:inbox!, :destination_id!, :template_id!, :reference_id!,
                    :parameters!, :locale]

  def perform
    check_opt_out!
    response = send_notification
    { success: true, response: response }
  rescue StandardError => e
    Rails.logger.error "[AMB Invitation] Failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def check_opt_out!
    raise 'Contact has opted out' if AppleInvitationOptOut.opted_out?(
      phone_number: destination_id,
      inbox_id: inbox.id
    )
  end

  def build_payload
    {
      'v' => 1,
      'id' => SecureRandom.uuid,
      'sourceId' => inbox.channel.msp_id,
      'destinationId' => destination_id,
      'interactiveData' => {
        'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        'data' => {
          'version' => '1.0',
          'requestIdentifier' => SecureRandom.uuid,
          'notification' => CaseTransformer.to_apple_format({
            'template_id'  => template_id,
            'locale'       => locale || 'en-us',
            'reference_id' => reference_id,
            'parameters'   => parameters
          })
        },
        'useLiveLayout' => true
      },
      'type' => 'interactive'
    }
  end

  def send_notification
    # Reuses channel's HTTP client but adds message-type: notification header
    inbox.channel.send_invitation(build_payload)
  end
end
```

### 1.5 Channel::AppleMessagesForBusiness — send_invitation method
**File**: `app/models/channel/apple_messages_for_business.rb`

Add:
```ruby
def send_invitation(payload)
  # Same as send_message but adds message-type: notification header
  SendMessageService.new(
    inbox: inbox,
    message: payload,
    extra_headers: { 'message-type' => 'notification' }
  ).send_to_apple
end
```

> ⚠️ Review `SendMessageService#send_to_apple` HTTP call implementation to thread `extra_headers` through the Faraday/HTTParty client correctly.

### 1.6 CloseSessionHandlerService
**File**: `app/services/apple_messages_for_business/close_session_handler_service.rb`

```ruby
class AppleMessagesForBusiness::CloseSessionHandlerService
  pattr_initialize [:inbox!, :params!]

  def perform
    phone_number = params['sourceId']
    reference_ids = params['referenceIds'] || []

    contact = find_or_lookup_contact(phone_number)
    return unless contact

    record_opt_out(contact, phone_number, reference_ids)
    add_activity_to_conversation(contact)
  end

  private

  def record_opt_out(contact, phone_number, reference_ids)
    AppleInvitationOptOut.find_or_initialize_by(
      account_id: inbox.account_id,
      phone_number: phone_number,
      inbox_id: inbox.id
    ).update!(
      contact: contact,
      opted_out_at: Time.current,
      reference_ids: reference_ids
    )
    Rails.logger.info "[AMB CloseSession] Opt-out recorded for #{phone_number}"
  end

  def add_activity_to_conversation(contact)
    conversation = inbox.conversations
                        .where(contact_id: contact.id)
                        .order(created_at: :desc).first
    return unless conversation

    conversation.messages.create!(
      message_type: :activity,
      content: I18n.t('apple_messages.invitation.user_left_conversation'),
      account_id: inbox.account_id
    )
  end

  def find_or_lookup_contact(phone_number)
    normalized = phone_number.gsub(/^tel:/, '')
    inbox.account.contacts.where(phone_number: normalized).first
  end
end
```

### 1.7 IncomingMessageService — CloseSession routing
**File**: `app/services/apple_messages_for_business/incoming_message_service.rb`

Add at the top of `perform`, before existing processing:
```ruby
if params['type'] == 'close'
  CloseSessionHandlerService.new(inbox: inbox, params: params).perform
  return
end
```

---

## Phase 2 — Campaign Integration

### 2.1 Campaign Model Extension
**File**: `app/models/campaign.rb`

```ruby
# In validate_campaign_inbox:
errors.add :inbox, 'Unsupported Inbox type' unless
  ['Website', 'Twilio SMS', 'Sms', 'Whatsapp', 'AppleMessagesForBusiness'].include? inbox.inbox_type

# In ensure_correct_campaign_attributes:
if ['Twilio SMS', 'Sms', 'Whatsapp', 'AppleMessagesForBusiness'].include?(inbox.inbox_type)
  self.campaign_type = 'one_off'
  self.scheduled_at ||= Time.now.utc
end

# In execute_campaign:
when 'AppleMessagesForBusiness'
  AppleMessages::OneoffInvitationCampaignService.new(campaign: self).perform
```

### 2.2 OneoffInvitationCampaignService
**File**: `app/services/apple_messages/oneoff_invitation_campaign_service.rb`

Mirrors `app/services/whatsapp/oneoff_campaign_service.rb`. Supports two audience targeting modes:
- `[{ type: 'Label', id: 123 }, ...]` — label-based (production batches)
- `[{ type: 'Phone', phone: 'tel:+1234567890' }, ...]` — direct phone list (testing/ad-hoc)

```ruby
class AppleMessages::OneoffInvitationCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    process_audience
    campaign.completed!
  end

  private

  delegate :inbox, to: :campaign

  def validate_campaign!
    raise 'Invalid campaign' unless campaign.inbox.inbox_type == 'AppleMessagesForBusiness' && campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?
    raise 'No template_params' if campaign.template_params.blank?
  end

  def process_audience
    label_contacts.each { |c| send_to_contact_phone(c.phone_number, c) }
    direct_phones.each  { |phone| send_to_contact_phone(phone, nil) }
  end

  def label_contacts
    label_ids = campaign.audience.select { |a| a['type'] == 'Label' }.pluck('id')
    return [] if label_ids.empty?

    labels = campaign.account.labels.where(id: label_ids).pluck(:title)
    campaign.account.contacts.tagged_with(labels, any: true)
  end

  def direct_phones
    campaign.audience.select { |a| a['type'] == 'Phone' }.pluck('phone')
  end

  def send_to_contact_phone(phone, contact)
    return Rails.logger.info '[AMB Campaign] Skipping - no phone' if phone.blank?

    dest = phone.start_with?('tel:') ? phone : "tel:#{phone}"
    return Rails.logger.info "[AMB Campaign] Skipping #{dest} - opted out" if opted_out?(dest)

    result = AppleMessagesForBusiness::SendInvitationService.new(
      inbox: inbox,
      destination_id: dest,
      template_id: campaign.template_params['template_id'],
      reference_id: build_reference_id(contact),
      parameters: campaign.template_params['parameters'] || {},
      locale: campaign.template_params['locale']
    ).perform

    store_message_record(contact, result) if result[:success]
  rescue StandardError => e
    Rails.logger.error "[AMB Campaign] Failed for #{dest}: #{e.message}"
  end

  def store_message_record(contact, _result)
    conversation = find_or_create_conversation(contact)
    return unless conversation

    conversation.messages.create!(
      message_type: :outgoing,
      content_type: :apple_invitation,
      content_attributes: {
        'invitation_template_id' => campaign.template_params['template_id'],
        'reference_id'           => build_reference_id(contact),
        'parameters'             => campaign.template_params['parameters'],
        'locale'                 => campaign.template_params['locale']
      },
      account_id: campaign.account_id
    )
  end

  def find_or_create_conversation(contact)
    return nil unless contact

    inbox.conversations.find_or_create_by!(
      contact_id: contact.id,
      account_id: campaign.account_id
    )
  end

  def opted_out?(dest)
    AppleInvitationOptOut.opted_out?(phone_number: dest, inbox_id: inbox.id)
  end

  def build_reference_id(contact)
    contact ? "campaign-#{campaign.id}-contact-#{contact.id}" : "campaign-#{campaign.id}-#{SecureRandom.hex(4)}"
  end
end
```

---

## Phase 3 — Template Management (Backend)

No schema change needed. Use existing `MessageTemplate` with:
- `category: 'notification'` (existing category)
- `supported_channels: ['apple_messages_for_business']`
- `metadata['invitation_template_id']` = Apple's templateId string (e.g. `binaryChoice.engage.withImage`)
- `metadata['invitation_locale']` = default locale
- `metadata['invitation_parameters']` = parameter definitions hash (field names + types)

### 3.1 MessageTemplate helper methods
**File**: `app/models/message_template.rb`

```ruby
def apple_invitation_template?
  apple_messages_template? && metadata['invitation_template_id'].present?
end

def invitation_template_id
  metadata['invitation_template_id']
end
```

### 3.2 Templates API
No controller change needed. Frontend queries:
```
GET /api/v1/accounts/:id/message_templates?channel=apple_messages_for_business&category=notification
```

### 3.3 I18n
**File**: `config/locales/en.yml`
```yaml
apple_messages:
  invitation:
    user_left_conversation: "User left the conversation and opted out of invitation messages."
    opt_out_recorded: "Opt-out recorded for this contact."
```

**File**: `app/javascript/dashboard/i18n/locale/en/en.json`
```json
"APPLE_MESSAGES": {
  "INVITATION": {
    "CAMPAIGN_TITLE": "Apple Messages Invitation",
    "TEMPLATE_LABEL": "Invitation Template",
    "REFERENCE_ID_LABEL": "Reference ID (e.g. order number)",
    "OPTED_OUT_BADGE": "Opted Out",
    "USER_LEFT": "User left the conversation"
  }
}
```

---

## Phase 4 — Frontend: Campaign UI

### 4.1 Campaign Store Extension
**File**: `app/javascript/dashboard/store/modules/campaigns.js`

Add `AppleMessagesForBusiness` to inbox-type checks (same pattern as WhatsApp).

### 4.2 New Components
**Dir**: `app/javascript/dashboard/components-next/Campaigns/CampaignPage/AppleMessagesCampaign/`

Model on `WhatsAppCampaign/` directory:

| File | Purpose |
|---|---|
| `AppleMessagesCampaignPage.vue` | Main listing page for AMB campaigns |
| `AppleMessagesCampaignDialog.vue` | Create/edit modal dialog |
| `AppleMessagesCampaignForm.vue` | Form with all fields (see below) |
| `InvitationTemplatePicker.vue` | Template selector with templateId + parameter preview |

**`AppleMessagesCampaignForm.vue` fields:**
- AMB Inbox selector
- `InvitationTemplatePicker` — fetches templates with `category=notification&channel=apple_messages_for_business`
- Reference ID prefix (optional, auto-appended with contact id)
- Locale override (optional)
- Audience toggle: **Labels** (multi-select) vs **Phone numbers** (textarea, one per line)
- Scheduled date/time picker (reuse existing `DateTimePicker`)

### 4.3 Dual Targeting Audience Format

```json
// Label-based (production)
[{ "type": "Label", "id": 42 }, { "type": "Label", "id": 17 }]

// Direct phones (testing)
[{ "type": "Phone", "phone": "tel:+14085551234" }]
```

### 4.4 Campaigns Routing
**File**: `app/javascript/dashboard/routes/dashboard/campaigns/campaigns.routes.js`

Add `apple_messages` route + tab in campaign navigation.

### 4.5 Campaign API template_params payload
```json
{
  "template_id": "binaryChoice.engage.withImage",
  "locale": "en-us",
  "parameters": {
    "brandName": "Acoustic House",
    "brandLogo": "<base64-png>"
  }
}
```

---

## Phase 5 — Frontend: Conversation Display

### 5.1 AppleInvitation Bubble
**File**: `app/javascript/dashboard/components-next/message/bubbles/AppleInvitation.vue`

Displays sent invitation in the conversation thread:
- Template ID badge
- Reference ID
- Parameters summary (brandName text, brandLogo image thumbnail)
- Status badge: **Delivered** / **Opted Out** (updated when CloseSession received)

### 5.2 Bubble Router
**File**: `app/javascript/dashboard/components-next/message/MessageBubble.vue`

Add case: `content_type === 'apple_invitation'` → render `<AppleInvitation />`

### 5.3 CloseSession Activity
`CloseSessionHandlerService` creates an `activity` message — existing activity rendering handles this automatically.

---

## Phase 6 — Composer Integration

**File**: `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue`

Add new tab `invitation`:
- `InvitationTemplatePicker.vue`
- Reference ID field (pre-filled with conversation ID, editable)
- Parameters form (dynamic fields from template's `invitation_parameters` definition)
- Locale selector (optional)
- Send → emits `sendAppleInvitation` → MessagesController dispatches `SendInvitationService`

**Backend**: `api/v1/accounts/:id/conversations/:id/messages` already receives messages — add `apple_invitation` to allowed `content_type` values and route to `SendInvitationService`.

---

## Phase 7 — Bot Integration (Deferred)

Add after core campaign + composer flows are stable.

**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

Add keyword `"invite"` → `SendInvitationService` with bot-specific templateId + parameters.

---

## Phase 8 — Testing (RSpec)

| Spec file | What it covers |
|---|---|
| `spec/models/apple_invitation_opt_out_spec.rb` | Validations, `opted_out?` scope |
| `spec/services/apple_messages_for_business/send_invitation_service_spec.rb` | Happy path, opt-out guard, payload structure, HTTP header |
| `spec/services/apple_messages_for_business/close_session_handler_service_spec.rb` | Opt-out recording, activity message, missing contact |
| `spec/services/apple_messages/oneoff_invitation_campaign_service_spec.rb` | Label + phone targeting, opt-out skip, message record creation, campaign completion |
| `spec/models/campaign_spec.rb` | AMB inbox validation, execute_campaign routing |
| `spec/services/apple_messages_for_business/incoming_message_service_spec.rb` | `type: "close"` routing |

**Key scenarios:**
- Opted-out contact → no HTTP call, returns error hash
- Valid send → payload contains `message-type: notification` header + correct `templateId`/`referenceId`
- CloseSession with known contact → opt-out row created + activity message in conversation
- CloseSession with unknown phone → graceful no-op
- Campaign with 3 contacts (1 opted-out, 1 no phone, 1 valid) → exactly 1 send + 1 message record

---

## Files Summary

### Modify
| File | Change |
|---|---|
| `app/models/campaign.rb` | Add AMB to allowlist + `execute_campaign` case |
| `app/models/channel/apple_messages_for_business.rb` | Add `send_invitation` method |
| `app/services/apple_messages_for_business/incoming_message_service.rb` | Route `type: "close"` early return |
| `app/services/apple_messages_for_business/case_transformer.rb` | Add `template_id`, `reference_id`, `brand_name`, `brand_logo` mappings |
| `app/models/message_template.rb` | Add `apple_invitation_template?`, `invitation_template_id` |
| `app/javascript/dashboard/store/modules/campaigns.js` | Add AMB type |
| `app/javascript/dashboard/routes/dashboard/campaigns/campaigns.routes.js` | Add apple_messages route + tab |
| `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue` | Add invitation tab |
| `config/locales/en.yml` | Add invitation i18n keys |
| `app/javascript/dashboard/i18n/locale/en/en.json` | Add APPLE_MESSAGES.INVITATION keys |

### Create (Backend)
- `db/migrate/TIMESTAMP_create_apple_invitation_opt_outs.rb`
- `app/models/apple_invitation_opt_out.rb`
- `app/services/apple_messages_for_business/send_invitation_service.rb`
- `app/services/apple_messages_for_business/close_session_handler_service.rb`
- `app/services/apple_messages/oneoff_invitation_campaign_service.rb`

### Create (Frontend)
- `components-next/Campaigns/CampaignPage/AppleMessagesCampaign/AppleMessagesCampaignPage.vue`
- `components-next/Campaigns/CampaignPage/AppleMessagesCampaign/AppleMessagesCampaignDialog.vue`
- `components-next/Campaigns/CampaignPage/AppleMessagesCampaign/AppleMessagesCampaignForm.vue`
- `components-next/Campaigns/CampaignPage/AppleMessagesCampaign/InvitationTemplatePicker.vue`
- `components-next/message/bubbles/AppleInvitation.vue`

### Create (Specs)
- `spec/models/apple_invitation_opt_out_spec.rb`
- `spec/services/apple_messages_for_business/send_invitation_service_spec.rb`
- `spec/services/apple_messages_for_business/close_session_handler_service_spec.rb`
- `spec/services/apple_messages/oneoff_invitation_campaign_service_spec.rb`

---

## Verification

```bash
# Unit tests
bundle exec rspec spec/models/apple_invitation_opt_out_spec.rb \
  spec/services/apple_messages_for_business/send_invitation_service_spec.rb \
  spec/services/apple_messages_for_business/close_session_handler_service_spec.rb \
  spec/services/apple_messages/oneoff_invitation_campaign_service_spec.rb

# Integration
bundle exec rspec spec/models/campaign_spec.rb \
  spec/services/apple_messages_for_business/incoming_message_service_spec.rb

# Lint
bundle exec rubocop -a
pnpm eslint:fix
```

**Manual E2E checklist:**
1. Create AMB invitation template in Settings → Templates (category: notification)
2. Create AMB campaign → select template → set audience → schedule
3. Trigger campaign → verify Apple MSP log shows `message-type: notification` header
4. Simulate CloseSession webhook → verify opt-out row created + activity in conversation
5. Retry campaign for opted-out contact → verify skip logged, no HTTP call
