# Apple Messages for Business — Invitations Implementation

**Status**: ✅ Active (deployed March 2026)
**Relevant commits**: `9018f12` (noImage + template fix), `b57f4ac` (fixes — close service, reopen service, opt-out flow)

---

## What Are Apple Invitations?

Apple Invitations (known in the Apple MSP protocol as "notification" messages) are **proactive outbound messages** that allow a business to invite customers into an Apple Messages for Business conversation — even when no conversation currently exists.

Key characteristics:

- Sent **to a phone number** (`tel:+1234567890` format), not to an existing conversation participant
- Use **Apple-managed templates** — the `templateId` is assigned by Apple (e.g. `binaryChoice.engage.withImage`)
- Are **opt-in gated** — customers tap to accept or decline; declining permanently opts them out for that inbox
- Support **template parameters** (brand name, logo)
- Carry a **reference ID** for business-side tracking (order numbers, campaign IDs, etc.)
- Distinguished from regular messages by the HTTP header `message-type: notification`

---

## Architecture Overview

```
Agent (Composer / Campaign)
  ↓
MessageBuilder → Message (content_type: apple_invitation)
  ↓ after_create_commit
SendReplyJob
  ↓
SendOnAppleMessagesForBusinessService#send_invitation_message
  ↓
SendInvitationService#perform
  ↓  check opt-out → build payload (CaseTransformer) → HTTP POST
Apple MSP API  (https://mspgw.push.apple.com/v1/message)
  ↓ customer declines (close + referenceIds webhook)
AppleMessagesForBusinessEventsJob
  ↓
CloseSessionHandlerService  →  AppleInvitationOptOut record
```

---

## Backend Components

### 1. `SendInvitationService`
**Location**: `app/services/apple_messages_for_business/send_invitation_service.rb`

Single invitation send. Inputs (via `pattr_initialize`):

| Argument | Description |
|---|---|
| `inbox` | The Apple Messages inbox |
| `destination_id` | Phone number (`tel:+1234567890`) |
| `template_id` | Apple-assigned template ID |
| `reference_id` | Business tracking ID |
| `parameters` | Hash of template parameters (snake_case internally) |
| `locale` | Language locale (defaults to `'en-us'`) |

**Flow**:
1. Calls `AppleInvitationOptOut.opted_out?` — raises if phone is opted out
2. Builds the MSP payload with `CaseTransformer.to_apple_format`
3. **Special case**: If `template_id` contains `'noimage'` (case-insensitive), the `brand_logo` parameter is stripped — Apple rejects it for no-image templates
4. `POST https://mspgw.push.apple.com/v1/message` with `message-type: notification` header
5. Returns `{ success: true }` or `{ success: false, error: ... }`

**Apple MSP Payload structure**:
```json
{
  "v": 1,
  "id": "<uuid>",
  "sourceId": "<business_msp_id>",
  "destinationId": "tel:+1234567890",
  "type": "interactive",
  "interactiveData": {
    "bid": "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension",
    "useLiveLayout": true,
    "data": {
      "version": "1.0",
      "requestIdentifier": "<uuid>",
      "notification": {
        "templateId": "binaryChoice.engage.withImage",
        "referenceId": "order-12345",
        "locale": "en-us",
        "parameters": {
          "brandName": "Acoustic House",
          "brandLogo": "<base64>"
        }
      }
    }
  }
}
```

**HTTP Headers**:
```
Content-Type: application/json
Authorization: Bearer <JWT>
id: <message_uuid>
Source-Id: <business_id>
Destination-Id: tel:+1234567890
message-type: notification        ← distinguishes from regular messages
```

---

### 2. `SendOnAppleMessagesForBusinessService`
**Location**: `app/services/apple_messages_for_business/send_on_apple_messages_for_business_service.rb`

Routes `content_type: 'apple_invitation'` to `send_invitation_message` (lines 31–32, 146–159).

```ruby
when 'apple_invitation'
  send_invitation_message
```

The `send_invitation_message` method reads `content_attributes` from the stored Message record and delegates to `SendInvitationService`.

---

### 3. `MessageProcessorService`
**Location**: `app/services/apple_messages_for_business/message_processor_service.rb`

Two invitation-specific behaviours:

- **Opt-out bypass** (line 16): `apple_invitation` messages are allowed to be sent even if the customer has previously opted out — invitations are the mechanism to re-engage them
- **Content type list** (line 67): `apple_invitation` is included in `apple_specific_content_type?` so it bypasses the rich-link URL processing path

---

### 4. `CloseSessionHandlerService`
**Location**: `app/services/apple_messages_for_business/close_session_handler_service.rb`

Handles the Apple MSP `close` webhook **that includes `referenceIds`** (the invitation opt-out signal).

**Flow**:
1. Extracts `sourceId` (phone) and `referenceIds` from webhook params
2. Finds contact by normalising the phone number (strips `tel:` prefix, queries `contacts.phone_number`)
3. `AppleInvitationOptOut.find_or_initialize_by(account, phone, inbox).update!(opted_out_at:, reference_ids:)`
4. Creates an activity message on the most recent conversation: `apple_messages.invitation.user_left_conversation`

> **Distinction from regular close**: A `close` event **without** `referenceIds` goes to `ConversationCloseService` (resolves conversation, blocks contact for regular messages). A `close` event **with** `referenceIds` goes to `CloseSessionHandlerService` (records invitation opt-out only).

---

### 5. `ConversationCloseService`
**Location**: `app/services/apple_messages_for_business/conversation_close_service.rb`

Handles regular conversation close (customer leaves without `referenceIds`):
- Resolves the conversation (`status: :resolved`)
- Sets `additional_attributes['closed_by'] = 'apple_messages_for_business'`
- Sets `contact.additional_attributes['apple_messages_blocked'] = true`
- Creates activity: *"Customer opted out… you shall offer to send an Apple Invitation."*

This is the trigger that surfaces the "send an invitation" suggestion to agents.

---

### 6. `ConversationReopenService`
**Location**: `app/services/apple_messages_for_business/conversation_reopen_service.rb`

Called by `IncomingMessageService` whenever a new message arrives. If the contact was previously blocked (opted out via regular close), this service:
- Removes the `apple_messages_blocked` flag from the contact
- Reopens the most recently AMB-closed conversation
- Creates activity: *"Customer reconnected via Apple Messages."*

This handles the Apple MSP rule that a customer can always re-initiate by sending a message, even after opting out.

---

### 7. `AppleMessagesForBusinessEventsJob`
**Location**: `app/jobs/webhooks/apple_messages_for_business_events_job.rb`

Routes `close` webhooks (lines 52–59):

```ruby
when 'close'
  if payload['referenceIds'].present?
    process_invitation_opt_out(channel, payload)   # → CloseSessionHandlerService
  else
    process_conversation_close(channel, payload, headers)  # → ConversationCloseService
  end
```

---

### 8. `AppleInvitationOptOut` (Model)
**Location**: `app/models/apple_invitation_opt_out.rb`

**Table**: `apple_invitation_opt_outs`

| Column | Type | Notes |
|---|---|---|
| `account_id` | bigint FK | |
| `contact_id` | bigint FK | |
| `inbox_id` | bigint FK | |
| `phone_number` | string | `tel:+...` format |
| `opted_out_at` | datetime | When opt-out was received |
| `reference_ids` | jsonb | Reference IDs from the close event |

**Unique index**: `(account_id, phone_number, inbox_id)` — one opt-out record per phone per inbox per account.

**Key method**:
```ruby
AppleInvitationOptOut.opted_out?(phone_number: 'tel:+1234567890', inbox_id: 42)
# => true / false
```

---

## Message Storage

Invitations are stored as `Message` records:

```ruby
{
  message_type: :outgoing,
  content_type: :apple_invitation,   # enum value 23
  content: "Apple Invitation: binaryChoice.engage.withImage",
  content_attributes: {
    'invitation_template_id' => 'binaryChoice.engage.withImage',
    'reference_id'           => 'order-12345',
    'locale'                 => 'en-us',
    'parameters'             => {
      'brand_name' => 'Acoustic House',
      'brand_logo' => '<base64>'
    },
    'opted_out'              => true   # set if customer subsequently opts out
  }
}
```

When `CloseSessionHandlerService` records an opt-out, it also marks existing invitation messages with `opted_out: true` in `content_attributes`, which causes the `AppleInvitation.vue` bubble to show the red "Opted Out" badge.

---

## Frontend Components

### `AppleInvitation.vue`
**Location**: `app/javascript/dashboard/components-next/message/bubbles/AppleInvitation.vue`

Displays sent invitations in the conversation thread:
- Bell icon + "Apple Messages Invitation" label
- Brand name (from `parameters.brand_name`)
- Friendly template name — `binaryChoice.engage.withImage` → `Binary Choice · With Image`
- Reference ID (hash icon)
- Locale (globe icon)
- Red "Opted Out" badge + notice when `content_attributes.opted_out` is true

### `AppleMessagesComposer.vue` (Invitation Tab)
**Location**: `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue`

The composer has an "Invitation" tab that:
- Loads `MessageTemplate` records filtered to `category === 'notification'` and `channel === 'apple_messages_for_business'`
- Shows a template selector (ComboBox)
- Shows a reference ID text input
- Send is disabled until both template and reference ID are filled
- On send: creates a message with `content_type: 'apple_invitation'` and the relevant `content_attributes`

---

## Template Requirements

Invitation templates are stored in the `message_templates` table:

| Field | Value |
|---|---|
| `name` | Descriptive name (e.g. "Binary Choice with Image") |
| `category` | `'notification'` |
| `supported_channels` | `['apple_messages_for_business']` |
| `metadata['invitation_template_id']` | Apple's templateId string |
| `metadata['invitation_locale']` | Default locale |
| `metadata['invitation_parameters']` | Parameter definitions hash |

Templates are fetched via:
```
GET /api/v1/accounts/:account_id/message_templates
    ?channel=apple_messages_for_business&category=notification
```

The `templates_controller.rb` was updated (commit `9018f12`) to filter by both `channel` and `category` query params.

---

## Case Normalization

All invitation data follows the standard AMB case convention:

| Internal (snake_case) | Apple MSP (camelCase) |
|---|---|
| `template_id` | `templateId` |
| `reference_id` | `referenceId` |
| `brand_name` | `brandName` |
| `brand_logo` | `brandLogo` |

`CaseTransformer.to_apple_format` handles the conversion in `SendInvitationService#build_payload`.

---

## Opt-Out Mechanics

There are **two separate opt-out mechanisms**:

| Mechanism | Trigger | Model/field | Effect |
|---|---|---|---|
| **Invitation opt-out** | `close` webhook + `referenceIds` | `AppleInvitationOptOut` | Blocks future invitations for that phone/inbox |
| **Regular message block** | `close` webhook without `referenceIds` | `contact.additional_attributes['apple_messages_blocked']` | Blocks regular outgoing messages |

The invitation opt-out check (`SendInvitationService#check_opt_out!`) uses `AppleInvitationOptOut` only.
The regular message block check (`MessageProcessorService`) uses `customer_opted_out?` which checks `apple_messages_blocked` on the contact.

`apple_invitation` content type **bypasses** the regular block check — invitations are the intended recovery mechanism.

---

## Incoming Invitation Response

When a customer **accepts** an invitation, Apple sends a regular `interactive` webhook with `data.notification.displayContent.determinateResponse`. This is handled in `IncomingMessageService#extract_content_from_interactive_data`:

```ruby
elsif data_keys.include?('notification')
  notification = interactive_data['data']['notification']
  determinate = notification&.dig('displayContent', 'determinateResponse')
  # Returns "title — subtitle" or 'Invitation Response'
end
```

The response is stored as a regular incoming `text` message in the conversation.

---

## Data Flow Summary

### Outbound (Agent → Apple)
```
1. Agent fills Invitation tab (template + reference ID)
2. POST /api/v1/accounts/:id/conversations/:id/messages
   { content_type: 'apple_invitation', content_attributes: { ... } }
3. MessageProcessorService — skips opt-out check for apple_invitation
4. Message record created (content_type: apple_invitation)
5. SendReplyJob triggered by after_create_commit
6. SendOnAppleMessagesForBusinessService routes to send_invitation_message
7. SendInvitationService:
   a. Check AppleInvitationOptOut — raise if opted out
   b. filtered_parameters strips brand_logo for noImage templates
   c. CaseTransformer converts snake_case → camelCase
   d. POST to mspgw.push.apple.com with message-type: notification
8. update_message_status sets source_id on success
9. AppleInvitation.vue bubble renders in conversation
```

### Inbound Opt-Out (Customer declines)
```
1. Customer taps "Leave" on invitation in iMessage
2. Apple MSP POST /webhooks/apple_messages_for_business
   { type: 'close', sourceId: 'tel:+...', referenceIds: ['order-12345'] }
3. AppleMessagesForBusinessEventsJob detects referenceIds → invitation opt-out
4. CloseSessionHandlerService:
   a. Find contact by phone_number
   b. AppleInvitationOptOut.find_or_initialize_by(...).update!(opted_out_at:, reference_ids:)
   c. Add activity message to most recent conversation
5. Future SendInvitationService calls raise "Contact has opted out"
```

### Re-engagement (Customer sends message after regular opt-out)
```
1. Customer sends any message
2. IncomingMessageService#set_contact calls ConversationReopenService
3. ConversationReopenService removes apple_messages_blocked flag
4. Reopens the AMB-closed conversation
5. Creates activity: "Customer reconnected via Apple Messages."
6. Agent can now send regular messages again
```

---

## File Reference

| File | Purpose |
|---|---|
| `app/services/apple_messages_for_business/send_invitation_service.rb` | Core invitation send |
| `app/services/apple_messages_for_business/close_session_handler_service.rb` | Invitation opt-out handler |
| `app/services/apple_messages_for_business/conversation_close_service.rb` | Regular close / block |
| `app/services/apple_messages_for_business/conversation_reopen_service.rb` | Unblock on customer re-message |
| `app/services/apple_messages_for_business/incoming_message_service.rb` | Incoming message + reopen trigger |
| `app/services/apple_messages_for_business/send_on_apple_messages_for_business_service.rb` | Routes apple_invitation to service |
| `app/services/apple_messages_for_business/message_processor_service.rb` | Opt-out bypass for invitations |
| `app/models/apple_invitation_opt_out.rb` | Opt-out persistence |
| `app/jobs/webhooks/apple_messages_for_business_events_job.rb` | Webhook routing |
| `app/javascript/dashboard/components-next/message/bubbles/AppleInvitation.vue` | UI bubble |
| `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue` | Invitation composer tab |
