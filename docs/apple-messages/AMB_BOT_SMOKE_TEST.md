# Plan: Acoustic House Bot Test Runner Script

## Context
The Acoustic House Bot (`AcousticHouseBotService`) demos every Apple Messages for Business feature type.
Currently you must send real keywords from a physical device to trigger each handler.
This script lets you fire any trigger — keyword or interactive — from a `rails runner` command,
sending real AMB messages to a target conversation without touching a device.

---

## File to create
`script/test_amb_bot.rb`

---

## Usage shape
```bash
rails runner script/test_amb_bot.rb -- INBOX_ID CONVERSATION_ID [options]

# Run all 30+ triggers sequentially (default):
rails runner script/test_amb_bot.rb -- 5 42

# Run one trigger:
rails runner script/test_amb_bot.rb -- 5 42 --trigger list_picker
rails runner script/test_amb_bot.rb -- 5 42 --trigger lp_guitar_0319

# Dry-run (stub HTTParty, no Apple MSP calls):
rails runner script/test_amb_bot.rb -- 5 42 --dry-run
rails runner script/test_amb_bot.rb -- 5 42 --trigger menu --dry-run
```

---

## Architecture

### Entry flow
1. Parse ARGV → inbox_id, conversation_id, optional --trigger, optional --dry-run
2. Load `Inbox.find(inbox_id)` → validate it's AMB channel
3. Load `Conversation.find(conversation_id)` → validate it belongs to that inbox
4. Install dry-run stubs if flag set
5. Iterate selected triggers; for each:
   a. Reset bot state on conversation
   b. Inject prerequisite sample data into `custom_attributes`
   c. Create a real `Message` (`message_type: :incoming, content_type: :text, sender: conversation.contact`)
   d. Instantiate `AcousticHouseBotService.new(conversation, message)`
   e. Call `process_message` OR `process_interactive_response(payload)`
   f. Print ✅/❌ result with elapsed time

---

## Trigger registry (all 30 triggers)

### Keyword triggers → `process_message` (service reads `message.content`)

| id | keyword | AMB feature |
|----|---------|-------------|
| `menu` | "menu" | Main menu list picker |
| `start_over` | "start over" | Reset / welcome |
| `summary` | "summary" | Summary list picker |
| `schedule` | "schedule" | Lesson scheduling flow |
| `list_picker` | "list picker" | List Picker demo |
| `time_picker` | "time picker" | Time Picker demo |
| `apple_pay` | "apple pay" | Apple Pay demo |
| `form` | "form" | Form demo |
| `large_form` | "large form" | Large Form demo |
| `ar` | "ar" | AR image + quick replies |
| `imessage` | "imessage" | iMessage App balloon (Shazam) |
| `authentication` | "authentication" | OAuth authentication menu |
| `appclip` | "appclip" | App Clip demo |
| `wallet` | "wallet" | Apple Wallet pass |

### Interactive triggers → `process_interactive_response(payload)`

| id | request_identifier | AMB feature | prerequisites seeded |
|----|--------------------|-------------|----------------------|
| `qr_travel` | `qr_travel` | Region quick reply | none |
| `qr_name` | `qr_name` | Name preference quick reply | `customer_name`, `stage_name` |
| `lp_guitar_0319` | `lp_guitar_0319` | Guitar list picker | none |
| `lp_store_selection` | `lp_store_selection` | Store list picker | `available_stores` (JSON array) |
| `qr_store_selection` | `qr_store_selection` | Store quick reply | `available_stores` (JSON array) |
| `applepay_1018` | `applepay_1018` | Apple Pay response (paid) | none |
| `qr_skip_payment` | `qr_skip_payment` | Skip payment quick reply | none |
| `time_0319` | `time_0319` | Time picker response | none |
| `qr_view_ar` | `qr_view_ar` | AR view question (yes) | none |
| `qr_place_ar` | `qr_place_ar` | AR place question (yes) | none |
| `qr_continue` | `qr_continue` | Continue quick reply (yes) | none |
| `qr_photo` | `qr_photo` | Photo question (yes) | none |
| `qr_learn_more` | `qr_learn_more` | Learn more (yes) | none |
| `lp_menu_0319` | `lp_menu_0319` | Menu selection (item 2) | none |
| `lp_summary_0319` | `lp_summary_0319` | Summary selection (item 7) | none |
| `form_large_content` | (via message content_type) | Large form response | none; uses `content_type: :apple_form_response` |
| `qr_oauth_provider` | `qr_oauth_provider` | OAuth provider (LinkedIn) | none |

---

## Sample payloads (standard format, not NSKeyedArchiver)

Each interactive payload includes a `'_test_nonce'` key set to `Time.current.to_f.to_s`
so the MD5 idempotency key is unique per run, bypassing the 2-minute Redis dedup guard.

```ruby
INTERACTIVE_PAYLOADS = {
  'qr_travel' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 0,
    'items' => [{ 'title' => 'Americas' }, { 'title' => 'EMEA' }, { 'title' => 'Asia Pacific' }] } } },

  'qr_name' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 0,
    'items' => [{ 'title' => 'John' }, { 'title' => 'Slash' }] } } },

  'lp_guitar_0319' => { 'data' => { 'listPicker' => { 'sections' => [
    { 'title' => 'You Selected', 'items' => [{ 'title' => 'Stratocaster', 'identifier' => '0' }] }
  ] } } },

  'lp_store_selection' => { 'data' => { 'listPicker' => { 'sections' => [
    { 'title' => 'You Selected', 'items' => [{ 'identifier' => '0' }] },
    { 'title' => 'Available Stores', 'items' => [{ 'title' => 'Apple Park Visitor Center' }] }
  ] } } },

  'qr_store_selection' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 0,
    'items' => [{ 'title' => 'Apple Park Visitor Center' }] } } },

  'applepay_1018' => { 'data' => { 'payment' => { 'state' => 'paid' } } },

  'qr_skip_payment' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 1,
    'items' => [{ 'title' => 'Try Again' }, { 'title' => 'Skip' }] } } },

  'time_0319' => { 'data' => { 'event' => { 'timeslots' => [
    { 'startTime' => 1.week.from_now.iso8601, 'formatted_time' => '2:00 PM' }
  ] } } },

  'qr_view_ar' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 0,
    'items' => [{ 'title' => 'Yes' }, { 'title' => 'No' }] } } },

  # qr_place_ar, qr_continue, qr_photo, qr_learn_more: same shape as qr_view_ar

  'lp_menu_0319' => { 'data' => { 'reply' => { 'identifier' => '2',
    'title' => '2. Send a List Picker' } } },

  'lp_summary_0319' => { 'data' => { 'reply' => { 'identifier' => '7' } } },

  'qr_oauth_provider' => { 'data' => { 'quick-reply' => { 'selectedIndex' => 0,
    'items' => [{ 'title' => 'LinkedIn' }] } } }
}
```

---

## Prerequisite seeding (auto-injected before relevant triggers)

```ruby
SAMPLE_PREREQS = {
  'qr_name' => {
    'customer_name' => 'John Doe',
    'stage_name' => 'Slash'
  },
  'lp_store_selection' => {
    'available_stores' => [
      { 'name' => 'Apple Park Visitor Center', 'latitude' => 37.3327,
        'longitude' => -122.0053, 'id' => 'apple-park-01' }
    ].to_json
  },
  'qr_store_selection' => {
    'available_stores' => # same as lp_store_selection
  }
}
```

---

## State reset (before each trigger)

```ruby
conversation.update!(custom_attributes: conversation.custom_attributes.merge(
  'bot_enabled' => true,
  'bot_state' => 'AHA1',
  'bot_state_updated_at' => Time.current.iso8601,
  'retry_count' => 0
).merge(prereqs_for_trigger))
```

---

## Dry-run stub

```ruby
if dry_run
  allow_httparty = Module.new do
    def self.post(*_args, **_kwargs)
      OpenStruct.new(success?: true, code: 200, body: '{}')
    end
  end
  stub_const = HTTParty.singleton_class
  original_post = HTTParty.method(:post)
  HTTParty.define_singleton_method(:post) { |*a, **k| allow_httparty.post(*a, **k) }
  # Restored after each trigger run
end
```

Alternative (simpler): prepend a module that intercepts `HTTParty.post` globally for the process lifetime, since it's a runner script (no teardown needed).

---

## `form_large_content` special case
This handler is invoked via `process_message` (not `process_interactive_response`) when the
message has `content_type: :apple_form_response`. Create the message with:
```ruby
Message.create!(
  conversation: conversation, account: account, inbox: inbox,
  content: 'Form submission',
  message_type: :incoming,
  content_type: :apple_form_response,
  content_attributes: {
    'form_response' => {
      'selections' => [
        { 'title' => 'Name', 'items' => [{ 'value' => 'John' }] },
        { 'title' => 'Email', 'items' => [{ 'value' => 'john@example.com' }] },
        { 'title' => 'Instrument', 'items' => [{ 'value' => 'Guitar' }] }
      ]
    }
  },
  sender: conversation.contact
)
```
Then call `service.process_message` (the form response content_type routing is inside process_message).

---

## Output format

```
================================================================================
Acoustic House Bot — Test Runner
================================================================================
Inbox:         id=5  (Apple Covent Garden)
Conversation:  id=42
Mode:          all triggers  |  dry-run: false
Triggers:      30
================================================================================

[01/30] menu — Main menu list picker
        ✅ SUCCESS (1234ms)

[02/30] list_picker — List Picker demo (keyword)
        ✅ SUCCESS (987ms)
...
[15/30] lp_guitar_0319 — Guitar selection (interactive)
        ✅ SUCCESS (543ms)
...
================================================================================
Summary: 28/30 succeeded | 2 failed
Failed: qr_learn_more (EXCEPTION: ...), form_large_content (API_ERROR: ...)
================================================================================
```

---

## Critical files (read-only reference)
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` — trigger routing
- `app/services/apple_messages_for_business/bot_state_manager.rb` — state storage/reset
- `app/services/apple_messages_for_business/bot_message_sender.rb` — message senders
- `app/models/message.rb` — Message model (content_type enum, validations)
- `script/test_image_fetch_service.rb` — template pattern for runner scripts

---

## Verification
```bash
# Smoke-test all triggers in dry-run first:
rails runner script/test_amb_bot.rb -- 5 42 --dry-run

# Then send real messages for specific features:
rails runner script/test_amb_bot.rb -- 5 42 --trigger list_picker
rails runner script/test_amb_bot.rb -- 5 42 --trigger lp_guitar_0319
rails runner script/test_amb_bot.rb -- 5 42 --trigger time_0319

# Full real run (sends to device):
rails runner script/test_amb_bot.rb -- 5 42
```
