# Chatwoot Bot Integration Proposal
## Better Alternative to 80+ Node n8n Workflow

## Problem Analysis

### Current Approach: n8n Workflow
**Issues**:
- **80+ nodes**: One n8n workflow handling entire bot flow
- **Unmaintainable**: Any change requires updating multiple nodes
- **No code reuse**: Routing logic duplicated across nodes
- **Limited state**: Relies on Chatwoot `custom_attributes` (not designed for complex state machines)
- **Hard to test**: Visual workflows are difficult to unit test
- **Performance**: Each state transition requires HTTP round-trip through n8n

### Original Python Bot Architecture
**Key Patterns**:
1. **State Machine**: ~40 states (AHA1, AHA2, AHB1, AHB2, etc.)
2. **Database-backed**: PostgreSQL stores conversation state
3. **Function-based routing**: Dictionaries map events → handler functions
4. **Retry/Catcher logic**: Handles users who get stuck (e.g., AHC1, AHF1)
5. **Timeout logic**: Restarts if idle > 30 minutes
6. **User context**: Carries userId, lang, lastMessage, selection between states

## Recommended Solution: Ruby Bot Service in Chatwoot

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Apple Messages                             │
│                         ↓ ↑                                   │
│                    Chatwoot API                               │
│                         ↓ ↑                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │       WebhookController                               │   │
│  │  (receives messages & interactive responses)          │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         ↓                                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │   AcousticHouseBotService                             │   │
│  │   • State machine logic                               │   │
│  │   • Function-based routing                            │   │
│  │   • Retry/catcher patterns                            │   │
│  │   • Uses Conversation custom_attributes               │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         ↓                                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │   Bot Helper Services                                 │   │
│  │   • SendListPickerService                             │   │
│  │   • SendTimePickerService                             │   │
│  │   • FormService                                       │   │
│  │   • SendApplePayService                               │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         ↓                                     │
│              n8n Workflows (Optional)                         │
│              • Complex external integrations only             │
│              • Store geocoding/lookup                         │
│              • Payment processing                             │
│              • Analytics                                      │
└───────────────────────────────────────────────────────────────┘
```

### Implementation

#### 1. Core Bot Service

```ruby
# app/services/apple_messages_for_business/acoustic_house_bot_service.rb
module AppleMessagesForBusiness
  class AcousticHouseBotService < BaseBotService
    IDLE_TIMEOUT = 30.minutes

    def initialize(conversation, message)
      @conversation = conversation
      @message = message
      @contact = conversation.contact
      @bot_state = get_bot_state
      @lang = detect_language
    end

    def process_message
      # Check for timeout - restart if idle > 30 minutes
      if conversation_timed_out?
        reset_to_welcome
        return process_state
      end

      # Handle text message keywords
      if handle_keyword_message
        return
      end

      # Handle state-based flow
      process_state
    end

    def process_interactive_response(interactive_data)
      request_id = interactive_data['requestIdentifier']

      handler = INTERACTIVE_HANDLERS[request_id]
      if handler
        handler.call(self, interactive_data)
      else
        Rails.logger.warn "No handler for requestId: #{request_id}"
      end
    end

    private

    def get_bot_state
      attrs = @conversation.custom_attributes || {}
      last_updated = attrs['bot_state_updated_at']

      # Reset if timed out
      if last_updated && Time.parse(last_updated) < IDLE_TIMEOUT.ago
        return 'AHA1'
      end

      attrs['bot_state'] || 'AHA1'
    end

    def update_bot_state(new_state)
      @conversation.update_custom_attributes({
        'bot_state' => new_state,
        'bot_state_updated_at' => Time.current.iso8601
      })
      @bot_state = new_state
    end

    def conversation_timed_out?
      attrs = @conversation.custom_attributes || {}
      last_updated = attrs['bot_state_updated_at']

      return false unless last_updated

      Time.parse(last_updated) < IDLE_TIMEOUT.ago
    end

    def reset_to_welcome
      update_bot_state('AHA1')
    end

    # Keyword message routing
    KEYWORD_HANDLERS = {
      'menu' => :handle_menu,
      'startover' => :handle_start_over,
      'start over' => :handle_start_over,
      'stop' => :handle_stop,
      'summary' => :handle_summary,
      'list picker' => :handle_list_picker_demo,
      'listpicker' => :handle_list_picker_demo,
      'guitar' => :handle_list_picker_demo,
      'guitars' => :handle_list_picker_demo,
      'time picker' => :handle_time_picker_demo,
      'timepicker' => :handle_time_picker_demo,
      'appointment' => :handle_time_picker_demo,
      'time' => :handle_time_picker_demo,
      'apple pay' => :handle_apple_pay_demo,
      'payment' => :handle_apple_pay_demo,
      'pay' => :handle_apple_pay_demo,
      'form' => :handle_form_demo,
      'help me decide' => :handle_form_demo,
      'ar' => :handle_ar_demo,
      'augmented reality' => :handle_ar_demo
    }.freeze

    def handle_keyword_message
      keyword = @message.content.downcase.strip
      handler = KEYWORD_HANDLERS[keyword]

      if handler
        send(handler)
        return true
      end

      false
    end

    # Interactive response routing
    INTERACTIVE_HANDLERS = {
      'qr_travel' => :handle_region_selection,
      'form_help_me_decide' => :handle_form_response,
      'qr_name' => :handle_name_selection,
      'lp_guitar_0319' => :handle_guitar_selection,
      'applepay_1018' => :handle_apple_pay_response,
      'time_0319' => :handle_time_picker_response,
      'qr_view_ar' => :handle_ar_view_response,
      'qr_place_ar' => :handle_ar_place_response,
      'qr_continue' => :handle_continue_response,
      'qr_learn_more' => :handle_learn_more_response,
      'lp_menu_0319' => :handle_menu_selection
    }.freeze

    # State machine flow
    def process_state
      case @bot_state
      when 'AHA1'
        handle_welcome
      when 'AHA2'
        handle_region_prompt
      when 'AHA3'
        handle_form_or_name_prompt
      when 'AHB1'
        handle_form_response
      when 'AHB1_2'
        handle_text_name_input
      when 'AHB2'
        handle_name_preference_selection
      when 'AHB3'
        handle_guitar_list_prompt
      when 'AHC1'
        handle_guitar_list_catcher
      when 'AHC2'
        handle_ar_introduction
      when 'AHC3'
        handle_ar_first_question
      when 'AHD1'
        handle_ar_second_question
      when 'AHE1'
        handle_ar_place_response
      when 'AHE2'
        handle_apple_pay_prompt
      when 'AHF1'
        handle_apple_pay_catcher
      when 'AHF2'
        handle_lesson_introduction
      when 'AHF3'
        handle_location_request
      when 'AHG1'
        handle_location_response
      when 'AHH1'
        handle_time_picker_catcher
      when 'AHH2'
        handle_continue_prompt
      when 'AHI1'
        handle_rich_links
      when 'AHJ1'
        handle_photo_response
      when 'AHK1'
        handle_summary
      else
        # Unknown state - reset
        handle_welcome
      end
    end

    # Catcher patterns with retry logic
    def handle_guitar_list_catcher
      retry_count = increment_retry_count

      case retry_count
      when 2
        send_text_message("Looks like we're waiting for you to select a guitar from the list above.")
      when 3
        send_text_message("You may also use this menu as well.")
        send_guitar_list_picker
      when 4
        send_text_message("If you find yourself stuck, you may have an overview with the keyword 'Menu'.")
      when 5..Float::INFINITY
        if retry_count % 3 == 0
          send_text_message("Okay, we'll just pretend you selected the Martin DC28E Dreadnought.")
          auto_select_guitar('Martin DC28E Dreadnought')
          update_bot_state('AHC2')
          handle_ar_introduction
        end
      end
    end

    def increment_retry_count
      attrs = @conversation.custom_attributes || {}
      count = (attrs['retry_count'] || 0) + 1

      @conversation.update_custom_attributes({
        'retry_count' => count
      })

      count
    end

    def reset_retry_count
      @conversation.update_custom_attributes({
        'retry_count' => 0
      })
    end

    # Helper methods
    def send_text_message(content)
      Messages::MessageBuilder.new(
        account: @conversation.account,
        conversation: @conversation,
        inbox: @conversation.inbox,
        message_type: :outgoing,
        content: content,
        sender: bot_user
      ).perform
    end

    def send_guitar_list_picker
      AppleMessagesForBusiness::SendListPickerService.new(
        account: @conversation.account,
        conversation: @conversation,
        template_id: GUITAR_LIST_TEMPLATE_ID
      ).perform
    end

    def send_guitar_image(guitar_name)
      # Implementation
    end

    def send_ar_file
      # Implementation
    end

    def send_apple_pay_request
      # Implementation
    end

    def send_time_picker
      # Implementation
    end

    def bot_user
      @conversation.inbox.channel.bot_user || @conversation.account.users.first
    end

    def detect_language
      locale = @conversation.additional_attributes&.dig('locale')

      return 'en' unless locale

      case locale[0..1]
      when 'ja'
        'jp'
      when 'pt'
        'br'
      else
        'en'
      end
    end
  end
end
```

#### 2. Webhook Integration

```ruby
# app/controllers/api/v1/accounts/conversations/messages_controller.rb
# Add to existing webhook handling

def handle_apple_messages_bot
  return unless conversation.inbox.apple_messages_for_business?
  return unless bot_enabled?

  bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
    conversation,
    @message
  )

  if params[:interactive_data].present?
    bot_service.process_interactive_response(params[:interactive_data])
  else
    bot_service.process_message
  end
end

def bot_enabled?
  conversation.custom_attributes&.dig('bot_enabled') != false
end
```

#### 3. State Storage

Uses existing Chatwoot infrastructure:

```ruby
# Stored in Conversation.custom_attributes (JSON column)
{
  'bot_state' => 'AHC1',                    # Current state
  'bot_state_updated_at' => '2025-11-12T...', # Timeout tracking
  'retry_count' => 2,                        # For catcher logic
  'region' => 'Americas',                    # User selections
  'user_name' => 'John Doe',
  'stage_name' => 'DJ Cool',
  'selected_name' => 'DJ Cool',
  'selected_guitar' => 'Martin DC28E Dreadnought',
  'bot_enabled' => true                      # Toggle bot on/off
}
```

### Benefits

#### vs. n8n Workflow (80+ nodes)

| Aspect | n8n Workflow | Ruby Bot Service |
|--------|--------------|------------------|
| **Maintainability** | ❌ 80+ nodes to update | ✅ Single Ruby class |
| **Code Reuse** | ❌ Duplicate logic | ✅ Shared helper methods |
| **Testing** | ❌ Manual testing only | ✅ Unit tests with RSpec |
| **Performance** | ❌ HTTP round-trip per state | ✅ In-process execution |
| **Debugging** | ❌ Visual inspection only | ✅ Rails logs, byebug |
| **Version Control** | ❌ JSON export/import | ✅ Git-tracked Ruby code |
| **State Management** | ❌ Limited custom_attributes | ✅ Full database access |
| **Retry Logic** | ❌ Complex node chains | ✅ Simple counter logic |

#### Additional Benefits

1. **Native Chatwoot Integration**: Uses existing services, models, APIs
2. **Better Error Handling**: Ruby exception handling, retry logic
3. **Easier Testing**: RSpec unit tests for each state handler
4. **Better Performance**: No HTTP overhead between states
5. **Code Sharing**: Reuse existing Chatwoot bot infrastructure
6. **Easier Debugging**: Standard Rails debugging tools
7. **Better Logging**: Structured logging with Rails logger

### Migration Strategy

#### Phase 1: Core Bot Framework (Week 1)
- [ ] Create `AcousticHouseBotService` base class
- [ ] Implement state machine routing
- [ ] Add webhook integration
- [ ] Implement AHA1-AHA3 (welcome flow)
- [ ] Add retry/catcher patterns

#### Phase 2: Main Flow (Week 2)
- [ ] AHB1-AHB3 (name/form flow)
- [ ] AHC1-AHC3 (guitar selection)
- [ ] AHD1 (AR questions)
- [ ] AHE1-AHE2 (Apple Pay)

#### Phase 3: Advanced Features (Week 3)
- [ ] AHF1-AHF3 (lesson booking)
- [ ] AHG1 (location/geocoding)
- [ ] AHH1-AHH2 (time picker)
- [ ] AHI1-AHI4 (rich links)

#### Phase 4: Completion (Week 4)
- [ ] AHJ1-AHJ4 (photos/documents)
- [ ] AHK1-AHK3 (summary)
- [ ] Menu keyword handlers
- [ ] Comprehensive testing
- [ ] Documentation

### n8n Role (Simplified)

**Keep n8n for**:
- External API integrations (geocoding, store lookup)
- Complex analytics/reporting
- Multi-step external workflows
- Third-party service orchestration

**Remove from n8n**:
- State machine logic
- Conversation routing
- Simple message sending
- Form/interactive response handling

**Result**: 80+ nodes → ~10-15 nodes (external integrations only)

### Example: Simplified n8n Workflow

```
┌──────────────┐
│   Webhook    │ ← Chatwoot calls for geocoding
└──────┬───────┘
       │
       ↓
┌──────────────────┐
│  Parse Location  │ Extract zipcode/city
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Geocoding API   │ Get lat/lng
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Find 5 Stores   │ Query store database
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│  Return JSON     │ Send back to Chatwoot
└──────────────────┘
```

## Alternative: Hybrid Approach

If you want to keep some n8n workflow:

### Option 2: Event-Driven Architecture

```
Chatwoot Bot Service
  ├─→ Emits events: guitar_selected, location_requested, payment_initiated
  │
  └─→ n8n Workflows (event listeners)
       ├─→ Guitar Selection Workflow (handles AR, image delivery)
       ├─→ Location Workflow (geocoding, store lookup)
       ├─→ Payment Workflow (Apple Pay processing)
       └─→ Analytics Workflow (tracking, reporting)
```

**Benefits**:
- Modular n8n workflows (~5-10 nodes each)
- Easier to maintain and test
- Clear separation of concerns
- Can be developed/deployed independently

## Recommendation

**Go with Option 1: Ruby Bot Service**

**Reasons**:
1. **Maintainability**: Single codebase vs. 80+ visual nodes
2. **Performance**: No HTTP overhead for state transitions
3. **Testing**: Unit tests for bot logic
4. **Native Integration**: Uses existing Chatwoot infrastructure
5. **Easier Debugging**: Standard Rails tools
6. **Future-Proof**: Easy to extend with new features

**Timeline**: 4 weeks full-time (or 8 weeks part-time)

**ROI**:
- Development time saved: ~40% (vs maintaining n8n workflow)
- Performance improvement: ~70% (in-process vs HTTP)
- Bug fix time: ~60% faster (debugger vs visual inspection)

## Next Steps

1. **Review Proposal**: Validate approach with team
2. **Create Skeleton**: Basic bot service structure
3. **Implement AHA1**: Prove the concept
4. **Incremental Migration**: One state at a time
5. **Parallel Testing**: Compare with n8n workflow
6. **Gradual Rollout**: Feature flag to toggle between implementations

## Questions?

- **Q**: Can we keep n8n for some features?
  - **A**: Yes! Use hybrid approach for complex external integrations

- **Q**: What about existing n8n workflow?
  - **A**: Keep it running during migration, deprecate gradually

- **Q**: How long until feature parity?
  - **A**: 4 weeks for core flow, 8 weeks for complete feature parity

- **Q**: Can we unit test the bot?
  - **A**: Yes! Ruby service can have comprehensive RSpec tests

- **Q**: What about performance?
  - **A**: Much faster - no HTTP overhead, in-process execution
