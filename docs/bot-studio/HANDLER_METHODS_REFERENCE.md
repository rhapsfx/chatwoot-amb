# Bot Studio Handler Methods Reference

## Overview

Handler methods are Ruby methods defined in bot service classes (like `AcousticHouseBotService`) that control bot behavior at each conversation state. When designing bot flows in Bot Studio, you reference these handler methods in nodes to specify what should happen at each step.

## Handler Method Types

### 1. State Handler Methods

State handlers are called automatically when the bot enters a specific state. They are mapped in the `process_state` method using the state ID.

**Location**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**State to Handler Mapping**:

| State ID | Handler Method | Purpose |
|----------|----------------|---------|
| `AHA1` | `handle_welcome` | Initial welcome message |
| `AHA2` | `handle_region_prompt` | Ask for customer region |
| `AHA3` | `handle_form_or_name_prompt` | Prompt for form or name input |
| `AHB1` | `handle_form_response` | Process form submission |
| `AHB1_2` | `handle_text_name_input` | Process text name input |
| `AHB2` | `handle_name_preference_catcher` | Catch name preference response |
| `AHB3` | `handle_guitar_list_prompt` | Show guitar selection list |
| `AHC1` | `handle_guitar_list_catcher` | Process guitar selection |
| `AHC2` | `handle_ar_introduction` | Introduce AR feature |
| `AHC3` | `handle_ar_first_question` | First AR interaction question |
| `AHD1` | `handle_ar_view_catcher` | Process AR view response |
| `AHE1` | `handle_ar_place_catcher` | Process AR placement response |
| `AHE2` | `handle_apple_pay_prompt` | Show Apple Pay payment option |
| `AHF1` | `handle_apple_pay_catcher` | Process Apple Pay response |
| `AHF1_skip` | (waiting state) | Waiting for skip payment response |
| `AHF2` | `handle_lesson_introduction` | Introduce lesson scheduling |
| `AHF3` | `handle_location_request` | Request customer location |
| `AHG1` | `handle_location_response` | Process location data |
| `AHG2` | (waiting state) | Waiting for store selection |
| `AHH1` | `handle_time_picker_catcher` | Process time picker response |
| `AHH2` | `handle_continue_prompt` | Ask if customer wants to continue |
| `AHI1` | `handle_rich_links` | Show rich link examples |
| `AHJ1` | (waiting state) | Waiting for photo attachment |
| `AHJ2` | `handle_documents_intro` | Introduce document features |
| `AHJ3` | `handle_pdf_document` | Send PDF document |
| `AHJ4` | `handle_learn_more_prompt` | Offer learn more options |
| `AHK0` | (waiting state) | Waiting for learn more response |
| `AHK1` | `handle_summary` | Show conversation summary |
| `AHK2` | `handle_final_message` | Final farewell message |
| `AHK3` | `handle_register_rich_link` | Registration rich link |
| `AH-restart` | `handle_welcome` | Restart flow from beginning |

### 2. Keyword Handler Methods

Keyword handlers respond to specific text keywords sent by users. These can trigger demo flows or control conversation flow.

**Demo Keywords** (trigger isolated demos):

| Keyword(s) | Handler Method | Purpose |
|-----------|----------------|---------|
| `list picker`, `listpicker`, `guitar`, `guitars` | `handle_list_picker_demo` | Demo list picker template |
| `time picker`, `timepicker` | `handle_time_picker_demo` | Demo time picker template |
| `apple pay`, `payment`, `pay` | `handle_apple_pay_demo` | Demo Apple Pay integration |
| `form`, `help me decide` | `handle_form_demo` | Demo simple form |
| `large form`, `big form` | `handle_large_form_demo` | Demo large form |
| `ar`, `augmented reality` | `handle_ar_demo` | Demo AR features |
| `imessage app`, `imessage extension`, `shazam` | `handle_imessage_app` | Demo iMessage app |
| `authentication`, `auth` | `handle_authentication_menu` | Show auth options |
| `appclip` | `handle_app_clip_demo` | Demo App Clip |

**Flow Control Keywords**:

| Keyword(s) | Handler Method | Purpose |
|-----------|----------------|---------|
| `menu` | `handle_menu` | Show main menu |
| `startover`, `start over`, `restart`, `begin`, `reset` | `handle_start_over` | Restart conversation |
| `stop` | `handle_stop` | Stop conversation |
| `summary` | `handle_summary` | Show summary |
| `skip` | `handle_skip_payment` | Skip payment step |
| `schedule`, `schedule lesson`, `lesson`, `appointment`, `time` | `handle_schedule_lesson` | Schedule lesson |

### 3. Interactive Handler Methods

Interactive handlers respond to user interactions with Apple Messages templates (List Pickers, Time Pickers, Quick Replies, Forms).

**Request Identifier to Handler Mapping**:

| Request Identifier | Handler Method | Purpose |
|-------------------|----------------|---------|
| `qr_travel` | `handle_region_selection` | Process region quick reply |
| `qr_name` | `handle_name_preference_selection` | Process name preference |
| `lp_guitar_0319` | `handle_guitar_selection` | Process guitar list picker |
| `lp_store_selection` | `handle_store_selection` | Process store list picker |
| `qr_store_selection` | `handle_store_selection_qr` | Process store quick reply |
| `applepay_1018` | `handle_apple_pay_response` | Process Apple Pay response |
| `qr_skip_payment` | `handle_skip_payment` | Process skip payment |
| `time_0319` | `handle_time_picker_response` | Process time picker selection |
| `qr_view_ar` | `handle_ar_view_response` | Process AR view response |
| `qr_place_ar` | `handle_ar_place_response` | Process AR place response |
| `qr_continue` | `handle_continue_response` | Process continue response |
| `qr_photo` | `handle_photo_response` | Process photo quick reply |
| `qr_learn_more` | `handle_learn_more_response` | Process learn more response |
| `lp_menu_0319` | `handle_menu_selection` | Process menu selection |
| `form_large_content` | `handle_large_form_response` | Process large form |
| `act_imessage_app` | `handle_imessage_app` | Launch iMessage app |
| `qr_oauth_provider` | `handle_oauth_provider_selection` | Process OAuth provider |

## Handler Method Implementation Pattern

All handler methods follow this general pattern:

```ruby
def handle_example_state
  # 1. Log entry
  log_info "[Bot] 🎯 handle_example_state called - State: #{@bot_state}"

  # 2. Send message(s) to customer
  send_text_message('Example message')

  # 3. Update conversation attributes (optional)
  update_conversation_attribute('key', 'value')

  # 4. Update bot state to next state
  update_bot_state('NEXT_STATE_ID')

  # 5. Call next handler or wait for response
  handle_next_state # or wait for user response
end
```

## Using Handler Methods in Bot Studio

### In State Nodes

1. **State ID Field**: Enter the state identifier (e.g., `AHA1`, `AHB2`)
2. **Handler Method Field**: Enter the handler method name (e.g., `handle_welcome`, `handle_form_response`)
3. The handler is automatically called when the bot enters this state

**Example State Node Configuration**:
```yaml
State ID: AHA1
Label: Welcome Message
Handler Method: handle_welcome
Description: Sends welcome message and prompts for region
```

### In Intent Nodes

1. **Keywords Field**: Enter trigger keywords (comma-separated)
2. **Handler Method Field**: Enter the handler from KEYWORD_HANDLERS
3. The handler is called when user message matches keywords

**Example Intent Node Configuration**:
```yaml
Keywords: form, help me decide
Handler Method: handle_form_demo
Description: Triggers form demo flow
```

### In Action Nodes

1. **Action Type**: Choose action type (send_message, update_state, etc.)
2. **Handler Method**: Enter the handler method to execute
3. Handler is called as part of action execution

## Typing Indicators

Typing indicators simulate the bot "typing" before sending messages, creating a more natural conversation flow.

**Configuration** (in `AcousticHouseBotService`):

```ruby
# Enable/disable typing indicators globally
TYPING_INDICATORS_ENABLED = true

# Delay in seconds before sending message
TYPING_INDICATOR_DELAY = 1.5
```

**Recommendations**:
- **Development**: Set to `false` for faster testing
- **Production**: Set to `true` for better UX
- **Delay**: 1-2 seconds is optimal (1.5s default)

**How It Works**:
When `TYPING_INDICATORS_ENABLED = true`, the bot sends typing indicator events to Apple Messages before each message, making it appear as if the bot is composing the response.

## Template Dependencies

The bot requires specific templates to function. These are defined in `REQUIRED_TEMPLATES`:

```ruby
REQUIRED_TEMPLATES = %w[
  ah_guitar_list_picker
  ah_guitar_info_form
  ah_large_form_demo
  ah_main_menu
  ah_ar_guitar
  ah_summary
]
```

**Verification**:
```ruby
# Check if all templates exist for account
result = AcousticHouseBotService.verify_templates_exist(account_id)

# Returns:
{
  all_present: true/false,
  found: [[id, name], ...],
  missing: ['template_name', ...]
}
```

## Creating Custom Handler Methods

To add new handler methods to your bot:

1. **Define the method** in your bot service class:
   ```ruby
   def handle_custom_flow
     send_text_message('Custom flow message')
     update_bot_state('CUSTOM_STATE')
   end
   ```

2. **Add to appropriate handler constant**:
   ```ruby
   # For keyword triggers
   DEMO_KEYWORDS = {
     # ...existing keywords
     'custom' => :handle_custom_flow
   }.freeze

   # For interactive triggers
   INTERACTIVE_HANDLERS = {
     # ...existing handlers
     'qr_custom' => :handle_custom_flow
   }.freeze
   ```

3. **Add state mapping** (if state-based):
   ```ruby
   def process_state
     case @bot_state
     # ...existing states
     when 'CUSTOM_STATE'
       handle_custom_flow
     end
   end
   ```

4. **Use in Bot Studio**:
   - Create State node with State ID: `CUSTOM_STATE`
   - Set Handler Method: `handle_custom_flow`

## Best Practices

1. **Naming Convention**: Use `handle_` prefix for all handler methods
2. **State IDs**: Use descriptive prefixes (e.g., `AHA` for Welcome flow, `AHB` for Name flow)
3. **Logging**: Always log handler entry with `log_info`
4. **State Updates**: Update state before waiting for user response
5. **Error Handling**: Include fallback handlers for unexpected states
6. **Typing Indicators**: Enable in production, disable in development
7. **Template Validation**: Verify required templates exist before deployment

## Troubleshooting

**Issue**: Handler method not found
- Check method name spelling matches exactly
- Verify method is defined in bot service class
- Check state/keyword/identifier mapping in constants

**Issue**: Handler not triggered
- Verify state ID matches case statement in `process_state`
- Check keyword matches entry in KEYWORD_HANDLERS
- Verify request identifier matches INTERACTIVE_HANDLERS

**Issue**: Handler called multiple times
- Check for duplicate handler calls in flow
- Verify state transitions are correct
- Review logs for unexpected state changes

## Reference Files

- **Bot Service**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- **Base Service**: `app/services/apple_messages_for_business/bot_service.rb`
- **Message Sending**: `app/services/apple_messages_for_business/send_message_service.rb`
- **Template Services**: `app/services/apple_messages_for_business/send_*_service.rb`
- **Bot Studio UI**: `app/javascript/dashboard/routes/dashboard/settings/agentBots/`

## Additional Resources

- [Bot Studio Architecture](./BOT_STUDIO_ARCHITECTURE.md)
- [Bot Studio Integration Plan](./BOT_STUDIO_INTEGRATION_PLAN.md)
- [Visual Bot Studio Implementation Plan](./VISUAL_BOT_STUDIO_IMPLEMENTATION_PLAN.md)
- [Apple Messages for Business Integration Status](../apple-messages/AMB_INTEGRATION_STATUS_REPORT.md)
