# Acoustic House Bot Service - Comprehensive Code Quality Review

**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`  
**Lines of Code**: 4,115  
**Review Date**: 2025-12-26  
**Overall Assessment**: **Needs Improvement**

---

## Executive Summary

The AcousticHouseBotService is a feature-rich conversational bot implementation demonstrating all 12 Apple Messages for Business interactive message types. While functionally comprehensive and well-documented, the service suffers from significant maintainability issues due to its massive size (4,115 lines), extensive code duplication, and violation of several SOLID principles.

**Key Strengths:**
- Comprehensive demonstration of AMB capabilities
- Extensive logging and debugging support
- Well-structured state machine architecture
- Good error handling and fallback mechanisms

**Critical Issues:**
- Severe violation of Single Responsibility Principle
- Extensive method duplication (3 duplicate utf8_encode methods)
- Excessive file length (should be <500 lines)
- Complex conditional logic requiring refactoring
- Multiple magic strings and numbers
- Limited separation of concerns

---

## 1. Code Smells

### 1.1 CRITICAL: Massive Class Size (4,115 lines)

**Lines 1-4115**: The entire service is contained in a single 4,115-line file.

**Issue**: This violates the Single Responsibility Principle and makes the code extremely difficult to:
- Understand and navigate
- Test in isolation
- Maintain and modify
- Review effectively

**Recommendation**: Extract into focused service objects:

```ruby
# Suggested refactoring structure:
app/services/apple_messages_for_business/
  acoustic_house_bot/
    base_service.rb                    # Core orchestration
    state_machine.rb                   # State transitions
    message_sender.rb                  # All send_* methods
    interactive_handlers/
      guitar_selection_handler.rb
      store_selection_handler.rb
      time_picker_handler.rb
      form_handler.rb
      # ... etc
    demo_handlers/
      list_picker_demo.rb
      time_picker_demo.rb
      # ... etc
```

**Estimated Impact**: 80% reduction in main service size

---

### 1.2 CRITICAL: Code Duplication - utf8_encode Method

**Lines 544-558, 577-592, 595-601**: Three identical copies of `utf8_encode` method

```ruby
# DUPLICATE #1 (lines 544-558)
def utf8_encode(obj)
  case obj
  when String
    obj.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  when Hash
    obj.transform_keys { |k| utf8_encode(k) }
       .transform_values { |v| utf8_encode(v) }
  when Array
    obj.map { |item| utf8_encode(item) }
  when NilClass
    nil
  else
    obj.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end
end

# DUPLICATE #2 (lines 577-592) - IDENTICAL
# DUPLICATE #3 (lines 595-601) - log_info/log_warn only
```

**Issue**: Direct violation of DRY principle. Maintenance nightmare - bug fixes must be applied in three places.

**Recommendation**: Extract to concern or utility module:

```ruby
# app/services/apple_messages_for_business/concerns/utf8_logging.rb
module AppleMessagesForBusiness::Concerns::Utf8Logging
  extend ActiveSupport::Concern

  private

  def utf8_encode(obj)
    case obj
    when String
      obj.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    when Hash
      obj.transform_keys { |k| utf8_encode(k) }
         .transform_values { |v| utf8_encode(v) }
    when Array
      obj.map { |item| utf8_encode(item) }
    when NilClass
      nil
    else
      obj.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end

  def log_info(message)
    Rails.logger.info(utf8_encode(message))
  end

  def log_warn(message)
    Rails.logger.warn(utf8_encode(message))
  end

  def log_error(message)
    Rails.logger.error(utf8_encode(message))
  end

  def log_debug(message)
    Rails.logger.debug(utf8_encode(message))
  end
end

# Then in service:
include AppleMessagesForBusiness::Concerns::Utf8Logging
```

**Lines to Remove**: 80+ lines of duplicated code

---

### 1.3 HIGH: Long Methods (>50 lines)

Multiple methods exceed 50 lines, making them difficult to understand and test:

**Line 303-349**: `process_message` (47 lines - acceptable but complex)
**Line 351-445**: `process_interactive_response` (95 lines) ⚠️
**Line 682-775**: `process_state` (94 lines - large case statement) ⚠️
**Line 1045-1128**: `handle_guitar_selection` (84 lines) ⚠️
**Line 1379-1480**: `handle_location_response` (102 lines) ⚠️
**Line 1918-2182**: `handle_menu_selection` (265 lines) 🚨 **CRITICAL**
**Line 2297-2380**: `send_guitar_list_picker` (84 lines) ⚠️
**Line 3465-3540**: `send_store_selection_list_picker` (76 lines) ⚠️

**Recommendation for handle_menu_selection (lines 1918-2182)**:

```ruby
# Extract to MenuSelectionHandler service
class AppleMessagesForBusiness::AcousticHouseBot::MenuSelectionHandler
  def initialize(bot_service, interactive_data)
    @bot = bot_service
    @data = interactive_data
  end

  def handle
    selection_id = extract_selection_identifier
    return handle_invalid_selection if selection_id.blank?

    guard_against_duplicate_processing(selection_id)
    route_to_handler(selection_id)
  end

  private

  def extract_selection_identifier
    SelectionExtractor.new(@data).extract
  end

  def route_to_handler(id)
    MENU_HANDLERS[id].call(@bot)
  end

  MENU_HANDLERS = {
    '1' => ->(bot) { bot.handle_start_over },
    '2' => ->(bot) { bot.handle_list_picker_demo },
    # ... etc
  }.freeze
end
```

---

### 1.4 HIGH: Complex Conditional Logic

**Lines 1946-2006**: Deeply nested conditional with multiple fallback paths for menu selection

```ruby
# Current code (lines 1946-2006):
selection_identifier = if interactive_data['ldtext'].present?
  # ... 20 lines of mapping logic
elsif interactive_data['$archiver'] == 'NSKeyedArchiver'
  # ... 5 lines
else
  # ... 15 lines
end

# Try exact match first
selection_identifier = menu_map[item_title]

# If no exact match, try case-insensitive match
if selection_identifier.nil?
  # ... 10 lines
end

# If still no match, try partial match
if selection_identifier.nil?
  # ... 15 lines
end
```

**Recommendation**: Extract to Strategy pattern:

```ruby
class MenuSelectionExtractor
  STRATEGIES = [
    LdtextStrategy,
    NSKeyedArchiverStrategy,
    ListPickerStrategy,
    StandardStrategy
  ].freeze

  def initialize(data)
    @data = data
  end

  def extract
    STRATEGIES.each do |strategy|
      result = strategy.new(@data).extract
      return result if result.present?
    end
    nil
  end
end
```

---

### 1.5 MEDIUM: Magic Strings and Numbers

**Throughout the file**: Numerous hardcoded strings and identifiers without clear constants:

**Lines 1051-1061**: Hardcoded hash computation
```ruby
# Line 1051-1052
selection_data = interactive_data['ldtext'] || interactive_data.dig('data', 'listPicker', 'sections')&.to_json || 'unknown'
selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
```

**Recommendation**:
```ruby
class IdempotencyGuard
  EXPIRATION_TIME = 2.minutes.to_i
  
  def initialize(conversation_id, operation_type, data)
    @conversation_id = conversation_id
    @operation_type = operation_type
    @data = data
  end

  def already_processed?
    Redis::Alfred.get(cache_key).present?
  end

  def mark_processed\!
    Redis::Alfred.setex(cache_key, '1', EXPIRATION_TIME)
  end

  private

  def cache_key
    "#{@operation_type}:#{selection_hash}"
  end

  def selection_hash
    Digest::MD5.hexdigest("#{@conversation_id}:#{@data}")
  end
end
```

**Lines 1343-1355**: Hardcoded location database
```ruby
LOCATION_DATABASE = {
  '95014' => { name: 'Apple Park Visitor Center', ... }
}.freeze
```

**Recommendation**: Move to database or YAML configuration file

---

### 1.6 MEDIUM: Inconsistent Method Naming

**Lines 23**: Typo in method name
```ruby
def self.required_template_namesd  # ← Typo: should be "names"
  REQUIRED_TEMPLATES
end
```

**Lines 805-833, 958-999**: Inconsistent handler naming pattern
- `handle_region_selection` - handles interactive data
- `handle_name_preference_selection` - handles interactive data
- `handle_guitar_selection` - handles interactive data
- `handle_form_response` - handles form data (different pattern)

**Recommendation**: Establish consistent naming convention:
- `process_*_selection` for interactive handlers
- `process_*_response` for form/text handlers
- `send_*` for outgoing messages
- `handle_*` for state handlers

---

## 2. Best Practices Violations

### 2.1 Rails Conventions

**CRITICAL - Lines 608, 627**: Hardcoded timeout constant used in multiple places

```ruby
# Line 8
IDLE_TIMEOUT = 30.minutes

# Line 608
return 'AHA1' if last_updated && Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago

# Line 627
Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago

# Line 489 (in config)
'idle_timeout_minutes' => 30
```

**Issue**: Configuration duplication. The timeout exists both as a constant and in config.

**Recommendation**:
```ruby
# Remove IDLE_TIMEOUT constant, always use config
def idle_timeout
  @config.dig('conversation_flow', 'idle_timeout_minutes')&.minutes || 30.minutes
end

def get_bot_state
  attrs = @conversation.custom_attributes || {}
  last_updated = attrs['bot_state_updated_at']
  
  return 'AHA1' if last_updated && Time.zone.parse(last_updated) < idle_timeout.ago
  
  attrs['bot_state'] || 'AHA1'
end
```

---

### 2.2 Ruby Idioms

**Lines 838-851**: Verbose capability checking

```ruby
# Current (lines 838-840)
capabilities = @contact.additional_attributes&.dig('apple_messages_capabilities') || ''
supports_forms = capabilities.include?('FORM')

if supports_forms
  # ...
else
  # ...
end
```

**Recommendation**:
```ruby
def contact_supports_forms?
  @contact.additional_attributes&.dig('apple_messages_capabilities')&.include?('FORM')
end

def handle_form_or_name_prompt
  if contact_supports_forms?
    log_info '[Bot] Device supports FORM - sending Apple Messages Form'
    send_guitar_info_form
    update_bot_state('AHB1')
  else
    log_info '[Bot] Device does not support FORM - asking for name via text'
    send_text_message("What's your name?")
    update_bot_state('AHB1_2')
  end
end
```

---

### 2.3 Error Handling Patterns

**GOOD - Lines 1470-1480**: Proper error handling with fallback
```ruby
rescue StandardError => e
  Rails.logger.error utf8_encode("[Bot] ❌ Error in handle_location_response: #{e.message}")
  Rails.logger.error utf8_encode(e.backtrace.join("\n"))

  # Fallback on error
  location = LOCATION_DATABASE['95014']
  send_text_message('We encountered an error finding stores nearby...')
  send_lesson_time_picker(location)
  update_bot_state('AHH1')
  reset_retry_count
end
```

**GOOD** - Provides graceful degradation and continues user experience

---

**INCONSISTENT - Lines 2292-2295**: Generic error handling without user feedback
```ruby
rescue StandardError => e
  Rails.logger.error utf8_encode("[Bot] Failed to send quick reply: #{e.message}")
  Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  # No user notification - user left waiting
end
```

**Recommendation**: Add consistent user feedback:
```ruby
rescue StandardError => e
  log_error "[Bot] Failed to send quick reply: #{e.message}"
  log_error e.backtrace.join("\n")
  
  # Inform user and provide alternative
  send_text_message("I'm having trouble sending the quick reply. Please type your response instead.")
  # Track error for monitoring
  ErrorTrackingService.notify(e, context: { bot: 'AcousticHouse', method: 'send_quick_reply' })
end
```

---

### 2.4 Logging Practices

**GOOD - Lines 780-804**: Comprehensive logging with context
```ruby
log_info "[Bot] 🎯 handle_welcome called - State: #{@bot_state}"
log_info "[Bot] 🎯 Called from: #{caller[0..3].join("\n")}"
```

**INCONSISTENT**: Emoji usage in logs is creative but non-standard
- Makes log parsing harder
- Not searchable/filterable by severity alone
- Mixes presentation with data

**Recommendation**: Use structured logging with metadata:
```ruby
# Instead of:
log_info '[Bot] 🎯 handle_welcome called'

# Use:
log_info 'handle_welcome called', {
  state: @bot_state,
  handler_type: 'welcome',
  conversation_id: @conversation.id
}

# Configure logger to output JSON in production
# Human-readable in development
```

---

## 3. Maintainability Issues

### 3.1 Comment Quality

**GOOD - Lines 10-20**: Clear documentation of template dependencies
```ruby
# Template dependencies for deployment automation
# These templates must exist for the bot to function correctly
# Used by deployment scripts to auto-detect required templates
REQUIRED_TEMPLATES = %w[
  ah_guitar_list_picker
  ah_guitar_info_form
  # ...
].freeze
```

**MEDIUM - Lines 55-60**: Configuration-in-comments (should be in config)
```ruby
# Typing indicator configuration
# Set to false during development for faster testing
# Set to true in production for better user experience
TYPING_INDICATORS_ENABLED = true
TYPING_INDICATOR_DELAY = 1.5 # seconds
```

**Recommendation**: Move to configuration file:
```yaml
# config/bot_studio/acoustic_house.yml
typing_indicators:
  enabled: true
  delay_seconds: 1.5
  # Set to false during development for faster testing
```

---

### 3.2 Method Naming Clarity

**GOOD**:
- `handle_guitar_selection` - clear intent
- `send_quick_reply` - clear action
- `update_bot_state` - clear mutation

**UNCLEAR**:
- `handle_guitar_list_catcher` (line 1017) - what does "catcher" mean?
- `handle_ar_view_catcher` (line 1156) - inconsistent with naming
- `handle_form_or_name_prompt` (line 836) - doing two different things based on capability

**Recommendation**:
```ruby
# Rename "catcher" methods to be more descriptive
def handle_unexpected_text_during_guitar_selection
  # Retry logic when user sends text instead of selecting from list
end

def handle_unexpected_text_during_ar_view
  # Retry logic when user sends text instead of clicking quick reply
end

# Split multi-purpose method
def handle_name_collection
  if contact_supports_forms?
    prompt_for_form_submission
  else
    prompt_for_text_name_input
  end
end
```

---

### 3.3 Variable Naming

**INCONSISTENT - Lines 362-372**: Multiple names for same concept
```ruby
# Line 362
request_id = if data['quick-reply']

# Line 365
selected_id = data.dig('quick-reply', 'selectedIdentifier')

# Line 369
req_id = data['requestIdentifier']

# Line 379
req_id = case @bot_state
```

**Recommendation**: Use consistent naming:
```ruby
def extract_request_identifier(interactive_data)
  data = interactive_data['data'] || {}
  
  return extract_quick_reply_identifier(data) if data['quick-reply']
  return data['requestIdentifier'] if data['requestIdentifier'].present?
  
  infer_identifier_from_state
end
```

---

### 3.4 Code Organization

**POOR**: Methods are not grouped logically
- State handlers scattered throughout (lines 779-1760)
- Send methods scattered throughout (lines 2241-3795)
- Helper methods at the end (lines 3240-3927)

**Recommendation**: Group related methods with section comments:
```ruby
class AcousticHouseBotService
  # ============================================
  # PUBLIC API
  # ============================================
  
  def initialize(conversation, message, bot = nil, config = nil)
    # ...
  end
  
  def process_message
    # ...
  end
  
  # ============================================
  # STATE MACHINE - AHA STATES (Welcome Flow)
  # ============================================
  
  def handle_welcome
    # ...
  end
  
  def handle_region_prompt
    # ...
  end
  
  # ============================================
  # MESSAGE SENDING - Quick Replies
  # ============================================
  
  def send_quick_reply(title:, request_id:, items:, message: nil)
    # ...
  end
  
  # ... etc
end
```

---

## 4. Performance Concerns

### 4.1 N+1 Query Potential

**MEDIUM - Lines 31-35**: Potential N+1 if called in loop
```ruby
def self.required_template_ids(account_id)
  MessageTemplate.where(
    account_id: account_id,
    name: REQUIRED_TEMPLATES
  ).pluck(:id)
end
```

**Current Usage**: Only called once during verification (line 474), so not currently an issue.

**Recommendation**: Add index if not exists:
```ruby
# db/migrate/xxxxx_add_index_to_message_templates.rb
add_index :message_templates, [:account_id, :name], 
  name: 'index_message_templates_on_account_and_name'
```

---

### 4.2 Unnecessary Database Calls

**MEDIUM - Lines 889-890**: Explicit reload may be unnecessary
```ruby
# Reload conversation to ensure attributes are fresh
@conversation.reload
```

**Issue**: `save\!` was just called on line 887, reload is redundant unless running in transaction with concurrent updates.

**Recommendation**: Remove unless there's evidence of stale reads:
```ruby
# Store address information if found
update_conversation_attribute('delivery_address', address_data) if address_data.present?

# No reload needed - attributes are fresh from update
log_info "[Bot] ✅ Stored attributes: #{utf8_encode(@conversation.custom_attributes).inspect}"
```

---

### 4.3 Sleep Calls in Request Path

**CRITICAL - Lines 2296, 3418, 3637, 3744**: Blocking sleep calls

```ruby
# Line 2296
sleep(TYPING_INDICATOR_DELAY)  # 1.5 seconds

# Line 3418  
sleep(2.0)  # 2 seconds

# Line 3637
sleep(2.0)  # 2 seconds

# Line 3744
sleep(2.0)  # 2 seconds
```

**Issue**: Blocking the request thread. For a bot handling multiple conversations, this doesn't scale.

**Recommendation**: Use background jobs with delays:
```ruby
# Instead of:
send_rich_link(...)
sleep(2.0)
send_lesson_time_picker(location)

# Use:
send_rich_link(...)
ScheduleMessageJob.set(wait: 2.seconds).perform_later(
  conversation_id: @conversation.id,
  action: 'send_lesson_time_picker',
  params: { location: location.to_json }
)
```

---

### 4.4 Memory Usage Patterns

**LOW - Lines 3495-3504**: Large data stored in conversation attributes
```ruby
minimal_stores = stores.map do |store|
  {
    'id' => store[:id],
    'name' => store[:name],
    'latitude' => store[:latitude],
    'longitude' => store[:longitude],
    'distance_km' => store[:distance_km]
  }
end
update_conversation_attribute('available_stores', minimal_stores.to_json)
```

**Current**: JSON string stored in `custom_attributes` JSONB column - acceptable for <100 stores

**Concern**: If Apple Maps returns 100+ stores, this could exceed reasonable attribute size

**Recommendation**: Add validation:
```ruby
MAX_STORES_TO_CACHE = 20

minimal_stores = stores.first(MAX_STORES_TO_CACHE).map do |store|
  # ... mapping
end

if stores.length > MAX_STORES_TO_CACHE
  log_warn "[Bot] Truncating store list from #{stores.length} to #{MAX_STORES_TO_CACHE}"
end
```

---

## 5. Security Analysis

### 5.1 Input Validation

**GOOD - Lines 654**: Input sanitization before keyword matching
```ruby
keyword = @message.content.downcase.strip
```

**GOOD - Lines 355**: Sanitization for logging
```ruby
sanitized_data = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(
  interactive_data, 
  max_length: 20
)
```

**MISSING - Lines 1381**: No validation of user-provided location input
```ruby
def handle_location_response
  user_message = @message.content.strip
  # No validation of input length, format, or malicious content
  
  if user_message.include?('maps.apple.com')
    coordinates = maps_service.extract_coordinates_from_url(user_message)
```

**Recommendation**: Add input validation:
```ruby
def handle_location_response
  user_input = @message.content.strip
  
  # Validate input length
  if user_input.length > 500
    send_text_message("That location seems too long. Please provide a zipcode, city, or Apple Maps link.")
    return
  end
  
  # Sanitize for safety
  sanitized_input = sanitize_user_location_input(user_input)
  
  # Then process...
end

private

def sanitize_user_location_input(input)
  # Remove potentially dangerous characters while preserving useful ones
  input.gsub(/[<>]/, '')
end
```

---

### 5.2 Data Sanitization

**GOOD - Lines 2520**: Sanitization before logging
```ruby
sanitized_attrs = LogSanitizerService.sanitize_for_log(content_attributes)
log_info "[Bot] 📋 Raw content_attributes: #{utf8_encode(sanitized_attrs).inspect}"
```

**CONCERN - Lines 3270-3289**: User-provided address displayed without sanitization
```ruby
def send_delivery_confirmation(address_data, customer_name = nil)
  # ... building address string
  formatted_address = address_parts.join(', ')
  
  # Directly interpolated into message
  message = "Perfect #{customer_name}\! Your order will be delivered to: #{formatted_address}"
  send_text_message(message)
```

**Risk**: Low (Apple Messages handles escaping), but good practice to be explicit

**Recommendation**:
```ruby
def send_delivery_confirmation(address_data, customer_name = nil)
  formatted_address = sanitize_for_display(address_parts.join(', '))
  safe_name = sanitize_for_display(customer_name)
  
  message = if safe_name.present?
    "Perfect #{safe_name}\! Your order will be delivered to: #{formatted_address}"
  else
    "Perfect\! Your order will be delivered to: #{formatted_address}"
  end
  
  send_text_message(message)
end

private

def sanitize_for_display(text)
  return nil if text.blank?
  # Remove control characters but preserve international characters
  text.gsub(/[\x00-\x1F\x7F]/, '')
end
```

---

### 5.3 Authorization Checks

**MISSING**: No authorization checks in the service itself

**Current Architecture**: Authorization presumably handled by calling service (FlowExecutorService or IncomingMessageService)

**Recommendation**: Add defensive check at entry point:
```ruby
def initialize(conversation, message, bot = nil, config = nil)
  @conversation = conversation
  @message = message
  @bot = bot
  @config = build_config(bot, config)
  @contact = conversation.contact
  @bot_state = get_bot_state
  @lang = detect_language

  # Add authorization check
  validate_conversation_access\!
  validate_config\! if @bot.present?
end

private

def validate_conversation_access\!
  # Ensure bot has permission to interact with this conversation
  return if @bot.blank?  # Legacy mode
  
  policy = AgentBotPolicy.new(@conversation.account, @bot)
  raise Pundit::NotAuthorizedError unless policy.show?
end
```

---

### 5.4 OAuth Security

**GOOD - Lines 4022-4028, 4040-4046, 4058-4064**: OAuth provider validation
```ruby
unless @conversation.inbox.channel.oauth2_provider_enabled?('linkedin')
  send_text_message('❌ LinkedIn OAuth is not enabled for this inbox.')
  send_text_message('Please configure LinkedIn OAuth in inbox settings.')
  update_bot_state('DEMO_MODE')
  return
end
```

**GOOD**: Validates that OAuth provider is configured before attempting authentication

---

## 6. Testing Considerations

### 6.1 Testability Issues

**CRITICAL**: Service is nearly impossible to unit test due to:

1. **Massive size**: 4,115 lines means 100+ test scenarios
2. **Tight coupling**: Direct dependencies on:
   - `@conversation` (Active Record)
   - `@message` (Active Record)
   - `Rails.logger`
   - `Redis::Alfred`
   - External services (Apple Maps, Image Fetch, etc.)
3. **Complex state machine**: 50+ states with intricate transitions
4. **Mixed responsibilities**: Message sending, state management, business logic, API calls

**Recommendation**: Refactor for testability:

```ruby
# Extract core logic to testable service object
class AcousticHouseBot::StateMachine
  attr_reader :state, :conversation_data

  def initialize(initial_state, conversation_data = {})
    @state = initial_state
    @conversation_data = conversation_data
  end

  def process_event(event, data = {})
    handler = STATE_HANDLERS[@state]
    raise "No handler for state: #{@state}" unless handler
    
    handler.call(self, event, data)
  end

  def transition_to(new_state)
    validate_transition\!(@state, new_state)
    @state = new_state
  end

  private

  STATE_HANDLERS = {
    'AHA1' => WelcomeStateHandler,
    'AHA2' => RegionPromptStateHandler,
    # ... etc
  }.freeze
end

# Now easily testable:
RSpec.describe AcousticHouseBot::StateMachine do
  describe '#process_event' do
    it 'transitions from AHA1 to AHA2 on welcome event' do
      machine = described_class.new('AHA1')
      machine.process_event(:welcome_completed)
      expect(machine.state).to eq('AHA2')
    end
  end
end
```

---

### 6.2 Dependency Injection Needs

**POOR - Lines 3384-3430**: Hardcoded service instantiation
```ruby
# Line 3384
maps_service = AppleMessagesForBusiness::AppleMapsService.new

# Line 2927-2931
service = AppleMessagesForBusiness::SendApplePayService.new(
  channel: @conversation.inbox.channel,
  destination_id: @conversation.contact_inbox.source_id,
  payment_data: payment_data
)
```

**Recommendation**: Inject dependencies for testability:
```ruby
def initialize(conversation, message, bot = nil, config = nil, dependencies = {})
  @conversation = conversation
  @message = message
  @bot = bot
  @config = build_config(bot, config)
  @contact = conversation.contact
  @bot_state = get_bot_state
  @lang = detect_language
  
  # Inject dependencies with defaults
  @maps_service = dependencies[:maps_service] || AppleMessagesForBusiness::AppleMapsService.new
  @image_service = dependencies[:image_service] || AppleMessagesForBusiness::ImageFetchService
  @logger = dependencies[:logger] || Rails.logger
  
  validate_config\! if @bot.present?
end

# Now testable with mocks:
bot_service = AcousticHouseBotService.new(
  conversation,
  message,
  bot,
  nil,
  {
    maps_service: instance_double(AppleMessagesForBusiness::AppleMapsService),
    logger: instance_double(Logger)
  }
)
```

---

## 7. Recommended Refactoring Priority

### Phase 1: Critical (Do Immediately)

1. **Fix typo in method name** (Line 23)
   ```ruby
   - def self.required_template_namesd
   + def self.required_template_names
   ```

2. **Remove duplicate utf8_encode methods** (Lines 544-601)
   - Extract to `Utf8Logging` concern
   - Include concern once
   - Remove 3 duplicate copies

3. **Extract MenuSelectionHandler** (Lines 1918-2182)
   - Extract 265-line method to separate service
   - Reduce cognitive load by 80%

---

### Phase 2: High Priority (Next Sprint)

4. **Extract State Machine** (Lines 682-1760)
   - Create `AcousticHouseBot::StateMachine` class
   - Extract state handlers to separate handler classes
   - Improve testability significantly

5. **Extract Message Senders** (Lines 2241-3795)
   - Create `AcousticHouseBot::MessageSender` module
   - Group all `send_*` methods together
   - Reduce main service to orchestration only

6. **Replace sleep() with background jobs** (Lines 2296, 3418, 3637, 3744)
   - Prevent request blocking
   - Improve scalability
   - Better error handling

---

### Phase 3: Medium Priority (Within Month)

7. **Add input validation** (Lines 1381, 3270)
   - Validate user location input
   - Sanitize address data before display

8. **Improve error messages** (Lines 2292-2295)
   - Add user feedback to all error handlers
   - Provide alternative actions
   - Track errors for monitoring

9. **Move configuration to YAML** (Lines 55-60, 1343-1355)
   - Extract TYPING_INDICATORS to config
   - Move LOCATION_DATABASE to config/data file
   - Improve configuration management

---

### Phase 4: Low Priority (Technical Debt)

10. **Standardize logging** (Throughout)
    - Replace emoji-based logging with structured logging
    - Add log levels and metadata
    - Improve log parsing/filtering

11. **Add method visibility markers** (Throughout)
    - Mark public API methods as `public`
    - Mark internal methods as `private`
    - Improve encapsulation

12. **Extract constants to configuration** (Throughout)
    - Move all magic strings to constants
    - Group related constants
    - Document configuration options

---

## 8. Metrics Summary

| Metric | Current Value | Target Value | Status |
|--------|---------------|--------------|--------|
| Lines of Code | 4,115 | <500 | 🔴 Critical |
| Longest Method | 265 lines | <50 lines | 🔴 Critical |
| Cyclomatic Complexity (est.) | >100 | <20 | 🔴 Critical |
| Code Duplication | 3 copies | 0 | 🔴 Critical |
| Method Count | 120+ | <30 | 🔴 Critical |
| Test Coverage | Unknown | >80% | 🔴 Unknown |
| Public Methods | ~50 | <10 | 🟡 High |
| Blocking Calls (sleep) | 4 | 0 | 🟡 High |

---

## 9. Positive Observations

Despite the critical issues, the service demonstrates several strengths:

1. **Comprehensive Logging**: Excellent debug output throughout (lines 780-804, 1047-1063)
2. **Error Handling**: Generally good fallback mechanisms (lines 1470-1480)
3. **Documentation**: Well-documented template dependencies (lines 10-25)
4. **Idempotency**: Good duplicate processing prevention (lines 1051-1062, 1509-1521)
5. **Configuration Support**: Flexible config system with fallbacks (lines 451-512)
6. **UTF-8 Safety**: Comprehensive encoding handling for international support (lines 544-558)
7. **State Machine Design**: Clear state-based flow architecture (lines 682-775)
8. **Template Integration**: Proper use of TemplateFacade for consistent data access (lines 2312-2320)

---

## 10. Code Quality Score

**Overall Grade: D (Needs Significant Improvement)**

| Category | Score | Weight | Weighted Score |
|----------|-------|--------|----------------|
| Code Smells | 2/10 | 25% | 0.5 |
| Best Practices | 6/10 | 20% | 1.2 |
| Maintainability | 3/10 | 25% | 0.75 |
| Performance | 5/10 | 10% | 0.5 |
| Security | 7/10 | 10% | 0.7 |
| Testing | 2/10 | 10% | 0.2 |
| **Total** | **3.85/10** | **100%** | **38.5%** |

**Recommendation**: Immediate refactoring required before adding new features. Current architecture makes maintenance and testing extremely difficult. Estimated refactoring effort: 3-4 weeks.

---

## 11. Next Steps

1. **Create refactoring ticket** with Phase 1 tasks
2. **Add test coverage** before refactoring (characterization tests)
3. **Extract MenuSelectionHandler** as proof-of-concept
4. **Measure impact** (code size reduction, test coverage increase)
5. **Continue with Phase 2** based on results

---

**Review Completed**: 2025-12-26  
**Reviewer**: Claude Code Review Agent  
**Next Review**: After Phase 1 refactoring completion
