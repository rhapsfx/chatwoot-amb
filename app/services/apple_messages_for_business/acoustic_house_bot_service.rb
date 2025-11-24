# frozen_string_literal: true

class AppleMessagesForBusiness::AcousticHouseBotService
  IDLE_TIMEOUT = 30.minutes

  # Typing indicator configuration
  # Set to false during development for faster testing
  # Set to true in production for better user experience
  TYPING_INDICATORS_ENABLED = false
  TYPING_INDICATOR_DELAY = 1.5 # seconds

  # Keyword message routing
  # Keywords that trigger template demos (isolated, don't continue flow)
  DEMO_KEYWORDS = {
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
    'large form' => :handle_large_form_demo,
    'big form' => :handle_large_form_demo,
    'ar' => :handle_ar_demo,
    'augmented reality' => :handle_ar_demo
  }.freeze

  # Keywords that control flow (reset, navigation, etc.)
  FLOW_CONTROL_KEYWORDS = {
    'menu' => :handle_menu,
    'startover' => :handle_start_over,
    'start over' => :handle_start_over,
    'restart' => :handle_start_over,
    'begin' => :handle_start_over,
    'reset' => :handle_start_over,
    'stop' => :handle_stop,
    'summary' => :handle_summary,
    'skip' => :handle_skip_payment,
    'schedule' => :handle_schedule_lesson,
    'schedule lesson' => :handle_schedule_lesson,
    'lesson' => :handle_schedule_lesson
  }.freeze

  # Combined keyword handlers for backward compatibility
  KEYWORD_HANDLERS = DEMO_KEYWORDS.merge(FLOW_CONTROL_KEYWORDS).freeze

  # Interactive response routing
  INTERACTIVE_HANDLERS = {
    'qr_travel' => :handle_region_selection,
    'qr_name' => :handle_name_preference_selection,
    'lp_guitar_0319' => :handle_guitar_selection,
    'lp_store_selection' => :handle_store_selection,
    'qr_store_selection' => :handle_store_selection_qr,
    'applepay_1018' => :handle_apple_pay_response,
    'qr_skip_payment' => :handle_skip_payment,
    'time_0319' => :handle_time_picker_response,
    'qr_view_ar' => :handle_ar_view_response,
    'qr_place_ar' => :handle_ar_place_response,
    'qr_continue' => :handle_continue_response,
    'qr_photo' => :handle_photo_response,
    'qr_learn_more' => :handle_learn_more_response,
    'lp_menu_0319' => :handle_menu_selection,
    'form_large_content' => :handle_large_form_response
  }.freeze

  def initialize(conversation, message)
    @conversation = conversation
    @message = message
    @contact = conversation.contact
    @bot_state = get_bot_state
    @lang = detect_language
  end

  def process_message
    # Check for timeout - restart if idle > 30 minutes
    timed_out = conversation_timed_out?
    if timed_out
      log_info '[Bot] ⏰ Conversation timed out, resetting to welcome'
      reset_to_welcome
      # Don't process state yet - let keyword handler run first
    end

    # Handle attachments (photos, documents)
    if @message.attachments.present?
      log_info '[Bot] 📎 Message has attachments, routing to handle_received_attachment'
      handle_received_attachment
      return
    end

    # Handle text message keywords (check BEFORE processing timed-out state)
    if handle_keyword_message
      log_info '[Bot] 🔑 Message handled by keyword handler'
      return
    end

    # If conversation timed out and no keyword was matched, now process welcome state
    return process_state if timed_out

    # Handle form responses by content_type (forms don't have custom identifiers)
    if @message.content_type == 'apple_form_response'
      log_info '[Bot] ✅ Detected form response, calling handle_form_response'

      # Check if this is a large form response (from template 343)
      # We identify it by checking the bot state or form content
      if @bot_state == 'DEMO_MODE_LARGE_FORM'
        log_info '[Bot] 📋 State is DEMO_MODE_LARGE_FORM, routing to handle_large_form_response'
        handle_large_form_response(@message.content_attributes)
      else
        log_info '[Bot] 📋 Routing to standard handle_form_response'
        handle_form_response
      end
      return
    end

    # If we reach here, no specific handler matched - fall through to state-based flow
    log_info "[Bot] ⚠️  No specific handler matched - falling through to process_state (state: #{@bot_state})"

    # Handle state-based flow
    process_state
  end

  def process_interactive_response(interactive_data)
    log_info '[Bot] 🎯 process_interactive_response called'

    # Sanitize interactive data to remove base64 image content from logs
    sanitized_data = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(interactive_data, max_length: 20)
    log_info "[Bot] 🎯 Interactive data: #{utf8_encode(sanitized_data).inspect}"

    # For quick replies, Apple uses 'selectedIdentifier' (our custom identifier)
    # For other types (list picker, time picker), use 'requestIdentifier'
    data = interactive_data['data'] || {}

    request_id = if data['quick-reply']
                   # Quick reply uses selectedIdentifier (the identifier we set on items)
                   selected_id = data.dig('quick-reply', 'selectedIdentifier')
                   log_info "[Bot] 🎯 Quick reply detected - selectedIdentifier: #{selected_id}"
                   selected_id
                 elsif data['requestIdentifier'].present?
                   # Other interactive types use requestIdentifier
                   req_id = data['requestIdentifier']
                   log_info "[Bot] 🎯 Interactive type detected - requestIdentifier: #{req_id}"
                   req_id
                 else
                   # NSKeyedArchiver format doesn't have 'data' key
                   # Infer requestIdentifier from bot state instead of searching old messages
                   log_info '[Bot] 🎯 NSKeyedArchiver format detected - inferring requestIdentifier from bot state'
                   log_info "[Bot] 🎯 Current bot state: #{@bot_state}"

                   # Map bot states to expected request identifiers
                   req_id = case @bot_state
                            when 'AHA2'
                              'qr_travel' # Region selection
                            when 'AHB1'
                              # Form response - but this shouldn't come through interactive path
                              # Route it to form handler manually
                              log_info '[Bot] 🎯 Form response detected via NSKeyedArchiver - routing to form handler'
                              handle_form_response
                              return # Exit early, form handler already called
                            when 'AHB2'
                              'qr_name' # Name preference
                            when 'AHC1'
                              'lp_guitar_0319' # Guitar list picker
                            when 'AHD1'
                              'qr_view_ar' # AR view question
                            when 'AHE1'
                              'qr_place_ar' # AR place question
                            when 'AHG2'
                              'lp_store_selection' # Store selection list picker
                            when 'AHH1'
                              'time_0319' # Time picker
                            when 'AHI1'
                              'qr_continue' # Continue prompt
                            when 'AHJ1'
                              'qr_photo' # Photo question
                            when 'AHK1'
                              'qr_learn_more' # Learn more question
                            when 'AHF1'
                              'applepay_1018' # Apple Pay
                            when 'DEMO_MODE'
                              'applepay_1018' # Apple Pay in demo mode
                            when 'DEMO_MODE_LARGE_FORM'
                              'form_large_content' # Large content form response
                            else
                              log_warn "[Bot] ⚠️ Unknown bot state for NSKeyedArchiver: #{@bot_state}"
                              nil
                            end

                   log_info "[Bot] 🎯 Inferred requestIdentifier from state #{@bot_state}: #{req_id}"
                   req_id
                 end

    log_info "[Bot] 🎯 Processing interactive response - requestId: #{request_id}"
    log_info "[Bot] 📋 Interactive data keys: #{utf8_encode(interactive_data.keys).inspect}"
    log_info "[Bot] 📋 Data keys: #{utf8_encode(data.keys).inspect}"

    handler_method = INTERACTIVE_HANDLERS[request_id]
    if handler_method
      log_info "[Bot] ✅ Found handler: #{handler_method}"
      send(handler_method, interactive_data)
    else
      log_warn "[Bot] ❌ No handler for requestId: #{request_id}"
      log_warn "[Bot] 📝 Available handlers: #{INTERACTIVE_HANDLERS.keys.inspect}"
    end
  end

  private

  # Ensure UTF-8 encoding for log output to prevent mojibake
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
      # For other objects, convert to string and encode
      obj.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end

  # Safe logging wrapper that ensures UTF-8 encoding
  def log_info(message)
    Rails.logger.info(utf8_encode(message))
  end

  def log_warn(message)
    Rails.logger.warn(utf8_encode(message))
  end

  def get_bot_state
    attrs = @conversation.custom_attributes || {}
    last_updated = attrs['bot_state_updated_at']

    # Reset if timed out
    return 'AHA1' if last_updated && Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago

    attrs['bot_state'] || 'AHA1'
  end

  def update_bot_state(new_state)
    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes['bot_state'] = new_state
    @conversation.custom_attributes['bot_state_updated_at'] = Time.current.iso8601
    @conversation.save!
    @bot_state = new_state
  end

  def conversation_timed_out?
    attrs = @conversation.custom_attributes || {}
    last_updated = attrs['bot_state_updated_at']

    return false unless last_updated

    Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago
  end

  def reset_to_welcome
    update_bot_state('AHA1')
    reset_retry_count
  end

  def handle_keyword_message
    return false if @message.content.blank?

    keyword = @message.content.downcase.strip

    # Check if it's a demo keyword (isolated template execution)
    if DEMO_KEYWORDS.key?(keyword)
      handler_method = DEMO_KEYWORDS[keyword]
      send(handler_method)

      # Set special state for large form to handle its response differently
      if handler_method == :handle_large_form_demo
        update_bot_state('DEMO_MODE_LARGE_FORM')
      else
        # Set demo mode state to prevent flow continuation
        update_bot_state('DEMO_MODE')
      end
      return true
    end

    # Check if it's a flow control keyword
    if FLOW_CONTROL_KEYWORDS.key?(keyword)
      handler_method = FLOW_CONTROL_KEYWORDS[keyword]
      send(handler_method)
      return true
    end

    false
  end

  # State machine flow
  def process_state
    log_info "[Bot] ⚙️ process_state - Handling state: #{@bot_state}"

    # If in demo mode, don't process state - wait for reset keyword
    if @bot_state == 'DEMO_MODE'
      send_text_message("Type 'startover' to begin the full experience, or try another demo keyword (form, ar, list picker, etc.)")
      return
    end

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
      handle_name_preference_catcher
    when 'AHB3'
      handle_guitar_list_prompt
    when 'AHC1'
      handle_guitar_list_catcher
    when 'AHC2'
      handle_ar_introduction
    when 'AHC3'
      handle_ar_first_question
    when 'AHD1'
      handle_ar_view_catcher
    when 'AHE1'
      handle_ar_place_catcher
    when 'AHE2'
      handle_apple_pay_prompt
    when 'AHF1'
      handle_apple_pay_catcher
    when 'AHF1_skip'
      # Waiting for skip payment quick reply response
      # No action needed - response will route through interactive handler
      send_text_message("Please select 'Skip Payment' or 'Try Again' from the options above.")
    when 'AHF2'
      handle_lesson_introduction
    when 'AHF3'
      handle_location_request
    when 'AHG1'
      handle_location_response
    when 'AHG2'
      # Store selection state - waiting for list picker response
      # Interactive handler will process the selection
      send_text_message('Please select a store from the list above.')
    when 'AHH1'
      handle_time_picker_catcher
    when 'AHH2'
      handle_continue_prompt
    when 'AHI1'
      handle_rich_links
    when 'AHJ1'
      # Waiting for photo quick reply response or photo attachment
      # This state is handled by interactive response handler (qr_photo) or attachment handler
      # No action needed - user already instructed to send photo after clicking Yes
    when 'AHJ2'
      handle_documents_intro
    when 'AHJ3'
      handle_pdf_document
    when 'AHJ4'
      handle_learn_more_prompt
    when 'AHK0'
      # Waiting for learn more quick reply response
      # Interactive handler will process the response
      send_text_message('Please select Yes or No from the options above.')
    when 'AHK1'
      handle_summary
    when 'AHK2'
      handle_final_message
    when 'AHK3'
      handle_register_rich_link
    when 'AH-restart'
      # Flow restart - go back to welcome
      handle_welcome
    else
      # Unknown state - reset
      log_warn "Unknown bot state: #{@bot_state}, resetting to welcome"
      reset_to_welcome
      handle_welcome
    end
  end

  # === AHA States (Welcome Flow) ===

  def handle_welcome
    log_info "[Bot] 🎯 handle_welcome called - State: #{@bot_state}"
    send_text_message('Thank you for contacting Acoustic Bot Prod.')
    send_text_message("Let's help you find your next guitar 🎸.")
    # Send region prompt immediately, update state in handle_region_prompt
    handle_region_prompt
  end

  def handle_region_prompt
    log_info "[Bot] 🎯 handle_region_prompt called - State: #{@bot_state}"
    log_info "[Bot] 🎯 Called from: #{caller[0..3].join("\n")}"
    # Update state here instead of in handle_welcome
    update_bot_state('AHA2') if @bot_state == 'AHA1'

    send_quick_reply(
      title: 'Select Region',
      request_id: 'qr_travel',
      message: 'Which region are you traveling from?',
      items: [
        { title: 'Americas', value: 'Americas' },
        { title: 'EMEA', value: 'EMEA' },
        { title: 'Asia Pacific', value: 'Asia Pacific' }
      ]
    )
  end

  def handle_region_selection(interactive_data)
    log_info '[Bot] 🌍 handle_region_selection called'
    log_info "[Bot] 🌍 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                  # NSKeyedArchiver format - extract title from $objects array
                  objects = interactive_data['$objects'] || []
                  # Find the selected region name in the objects array
                  # Look for strings that match region names
                  region_name = objects.find { |obj| obj.is_a?(String) && obj.match?(/Americas|EMEA|Asia Pacific/i) }
                  log_info "[Bot] 🌍 NSKeyedArchiver region selection: #{utf8_encode(region_name)}"
                  region_name
                else
                  # Standard quick reply format
                  quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                  selected_index = quick_reply_data['selectedIndex']
                  items = quick_reply_data['items'] || []

                  selected_title = items[selected_index]&.fetch('title', nil) if selected_index
                  log_info "[Bot] 🌍 Standard format region selection: #{utf8_encode(selected_title)}"
                  selected_title
                end

    update_conversation_attribute('region', selection)

    send_text_message("Great! You selected #{selection}.")
    update_bot_state('AHA3')
    handle_form_or_name_prompt
  end

  def handle_form_or_name_prompt
    # Check if device supports Apple Messages Forms
    capabilities = @contact.additional_attributes&.dig('apple_messages_capabilities') || ''
    supports_forms = capabilities.include?('FORM')

    if supports_forms
      log_info '[Bot] Device supports FORM - sending Apple Messages Form'
      send_guitar_info_form
      update_bot_state('AHB1') # Wait for form response
    else
      log_info '[Bot] Device does not support FORM - asking for name via text'
      send_text_message("What's your name?")
      # Skip form and ask for text name input
      update_bot_state('AHB1_2') # Wait for text name input
    end
  end

  # === AHB States (Name & Form Flow) ===

  def handle_form_response
    # Parse form response from content_attributes
    form_data = @message.content_attributes.dig('form_response', 'selections') || []

    log_info "[Bot] 📝 Parsing form response with #{form_data.length} selections"
    log_info "[Bot] 📝 Full form_data structure: #{utf8_encode(form_data).inspect}"

    # Log each section to understand the structure
    form_data.each_with_index do |section, index|
      log_info "[Bot] 📝 Section #{index}: #{utf8_encode(section).inspect}"
    end

    # Extract customer name by matching field title (case-insensitive)
    full_name_section = form_data.find { |section| section['title']&.downcase&.include?('full') && section['title']&.downcase&.include?('name') }
    customer_name = full_name_section&.dig('items', 0, 'value')

    # Extract stage name by matching field title (case-insensitive)
    stage_name_section = form_data.find { |section| section['title']&.downcase&.include?('stage') && section['title']&.downcase&.include?('name') }
    stage_name = stage_name_section&.dig('items', 0, 'value')

    # Extract address information
    address_data = extract_address_from_form(form_data)

    log_info "[Bot] 📝 Extracted customer_name: #{utf8_encode(customer_name).inspect} (from '#{utf8_encode(full_name_section&.dig('title'))}' field)"
    log_info "[Bot] 📝 Extracted stage_name: #{utf8_encode(stage_name).inspect} (from '#{utf8_encode(stage_name_section&.dig('title'))}' field)"
    log_info "[Bot] 📝 Extracted address: #{utf8_encode(address_data).inspect}"

    # Store in conversation attributes
    update_conversation_attribute('customer_name', customer_name) if customer_name.present?
    update_conversation_attribute('stage_name', stage_name) if stage_name.present?

    # Store address information if found
    update_conversation_attribute('delivery_address', address_data) if address_data.present?

    # Reload conversation to ensure attributes are fresh
    @conversation.reload

    log_info "[Bot] ✅ Form parsed - customer_name: #{utf8_encode(customer_name)}, stage_name: #{utf8_encode(stage_name)}, address: #{address_data.present? ? 'Yes' : 'No'}"
    log_info "[Bot] ✅ Stored attributes: #{utf8_encode(@conversation.custom_attributes).inspect}"

    # Thank user - use generic message if both names present (we'll ask which to use next)
    if customer_name.present? && stage_name.present?
      # Both names present - don't assume which to use yet
      send_text_message('Thank you for your submission!')
    else
      # Only one name - safe to use it
      send_text_message("Thank you#{customer_name.present? ? ", #{customer_name}" : ''}!")
    end

    # Send delivery confirmation if address was provided
    send_delivery_confirmation(address_data, customer_name) if address_data.present?

    # Check if we're in demo mode - if so, stop here
    if @bot_state == 'DEMO_MODE'
      log_info '[Bot] 📝 In DEMO_MODE - stopping after form response'
      send_text_message("Type 'startover' to restart the conversation.")
      return
    end

    # Normal flow: Ask for name preference via quick reply
    update_bot_state('AHB2')
    handle_name_preference_prompt
  end

  def handle_text_name_input
    # Handle plain text name input (for devices without form support)
    customer_name = @message.content.strip
    update_conversation_attribute('customer_name', customer_name)

    send_text_message("Thank you, #{customer_name}!")

    # Skip name preference (no stage name to choose from) - go directly to guitar list
    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def handle_name_preference_prompt
    # Ask user how they prefer to be addressed
    customer_name = get_conversation_attribute('customer_name')
    stage_name = get_conversation_attribute('stage_name')

    log_info "[Bot] 🏷️ handle_name_preference_prompt - customer_name: #{utf8_encode(customer_name).inspect}, stage_name: #{utf8_encode(stage_name).inspect}"
    log_info "[Bot] 🏷️ All conversation attributes: #{utf8_encode(@conversation.custom_attributes).inspect}"

    # If both names are present, ask for preference
    if customer_name.present? && stage_name.present?
      send_quick_reply(
        title: 'Name Preference',
        request_id: 'qr_name',
        message: 'How would you prefer to be addressed?',
        items: [
          { title: customer_name, value: 'real_name' },
          { title: stage_name, value: 'stage_name' }
        ]
      )
    else
      # Only one name available - skip to guitar list
      log_warn "[Bot] ⚠️ Skipping name preference - customer_name: #{utf8_encode(customer_name).inspect}, stage_name: #{utf8_encode(stage_name).inspect}"
      update_bot_state('AHB3')
      handle_guitar_list_prompt
    end
  end

  def handle_name_preference_selection(interactive_data)
    log_info '[Bot] 🏷️ handle_name_preference_selection called'
    log_info "[Bot] 🏷️ interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"

    # Extract selected name - handle both standard format and NSKeyedArchiver
    selection = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                  # NSKeyedArchiver format - extract title from $objects array
                  objects = interactive_data['$objects'] || []
                  # Find the selected name in the objects array (look for strings)
                  name = objects.find { |obj| obj.is_a?(String) && obj.length > 1 && obj != '$null' && !obj.start_with?('NS') }
                  log_info "[Bot] 🏷️ NSKeyedArchiver name selection: #{utf8_encode(name)}"
                  name
                else
                  # Standard quick reply format
                  quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                  selected_index = quick_reply_data['selectedIndex']
                  items = quick_reply_data['items'] || []

                  selected_title = items[selected_index]&.fetch('title', nil) if selected_index
                  log_info "[Bot] 🏷️ Standard format name selection: #{utf8_encode(selected_title)}"
                  selected_title
                end

    # Determine which name was selected
    customer_name = get_conversation_attribute('customer_name')
    stage_name = get_conversation_attribute('stage_name')

    preferred_name = if selection == customer_name
                       'real_name'
                     elsif selection == stage_name
                       'stage_name'
                     else
                       'real_name' # default
                     end

    update_conversation_attribute('preferred_name', preferred_name)

    send_text_message("Great! I'll call you #{selection}.")

    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  # Defensive catcher for text input when Quick Reply is expected (AHB2)
  def handle_name_preference_catcher
    log_info '[Bot] 🛡️ handle_name_preference_catcher called - user sent text instead of selecting Quick Reply'
    send_text_message('Please select either your full name or stage name from the options above.')
  end

  def handle_guitar_list_prompt
    log_info '[Bot] 🎸 handle_guitar_list_prompt called'
    send_text_message('Here are some amazing guitars:')
    send_guitar_list_picker
    update_bot_state('AHC1')
    log_info '[Bot] 🎸 Guitar list prompt completed, state updated to AHC1'
  end

  # === AHC States (Guitar Selection & Catcher) ===

  def handle_guitar_list_catcher
    retry_count = increment_retry_count

    case retry_count
    when 1
      # First message received after showing list - user might be typing
      send_text_message('Please select a guitar from the list above.')
    when 2
      send_text_message("Looks like we're waiting for you to select a guitar from the list.")
    when 3
      send_text_message('You may also use this menu as well.')
      send_guitar_list_picker
    when 4
      send_text_message("If you find yourself stuck, you may have an overview with the keyword 'Menu'.")
    else
      # After 5+ retries, auto-select every 3rd attempt
      if retry_count >= 5 && (retry_count % 3).zero?
        send_text_message("Okay, we'll just pretend you selected the Martin DC28E Dreadnought.")
        auto_select_guitar('Martin DC28E Dreadnought')
        reset_retry_count
        update_bot_state('AHC2')
        handle_ar_introduction
      else
        send_text_message('Still waiting for your guitar selection...')
      end
    end
  end

  def handle_guitar_selection(interactive_data)
    log_info '[Bot] 🎸 handle_guitar_selection called'
    log_info "[Bot] 🎸 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"
    log_info "[Bot] 🎸 FULL interactive_data structure: #{utf8_encode(interactive_data).inspect}"

    # Idempotency guard: prevent processing the same guitar selection twice
    selection_data = interactive_data['ldtext'] || interactive_data.dig('data', 'listPicker', 'sections')&.to_json || 'unknown'
    selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
    selection_key = "guitar_selection:#{selection_hash}"

    if Redis::Alfred.get(selection_key).present?
      log_info "[Bot] 🎸 Guitar selection already processed (hash: #{selection_hash}), skipping"
      return
    end

    # Mark as processed (expires after 2 minutes)
    Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
    log_info "[Bot] 🎸 Guitar selection marked as processed (hash: #{selection_hash})"

    # Extract selection from interactive data
    # For list picker responses from IDR, the selection is in the 'ldtext' field
    selection = if interactive_data['ldtext'].present?
                  # Resolved NSKeyedArchiver/IDR format - selection is in ldtext
                  guitar_name = interactive_data['ldtext']
                  log_info "[Bot] 🎸 IDR format guitar selection (ldtext): #{utf8_encode(guitar_name)}"
                  guitar_name
                elsif interactive_data['$archiver'] == 'NSKeyedArchiver'
                  # Raw NSKeyedArchiver format - extract from $objects array
                  objects = interactive_data['$objects'] || []
                  guitar_name = objects.find do |obj|
                    obj.is_a?(String) && obj.match?(/guitar|stratocaster|les paul|dreadnought|gibson|fender|martin|prs|taylor|r8/i)
                  end
                  log_info "[Bot] 🎸 NSKeyedArchiver guitar selection: #{utf8_encode(guitar_name)}"
                  guitar_name
                else
                  # Standard format - extract from listPicker sections
                  data = interactive_data['data'] || {}
                  list_picker = data['listPicker'] || {}
                  sections = list_picker['sections'] || []

                  # Find the selected item across all sections
                  guitar_name = nil
                  sections.each do |section|
                    items = section['items'] || []
                    selected_item = items.find { |item| item['title'].present? }
                    next unless selected_item

                    guitar_name = selected_item['title']
                    log_info "[Bot] 🎸 Standard format (listPicker) guitar selection: #{utf8_encode(guitar_name)}"
                    break
                  end

                  # Fallback to old reply format if list picker format didn't work
                  if guitar_name.blank?
                    guitar_name = interactive_data.dig('data', 'reply', 'title')
                    log_info "[Bot] 🎸 Standard format (reply) guitar selection: #{utf8_encode(guitar_name)}"
                  end

                  log_info "[Bot] 🎸 Guitar name after all attempts: #{utf8_encode(guitar_name).inspect}"
                  guitar_name
                end

    # Fallback if selection is blank - log warning and use default
    if selection.blank?
      log_warn "[Bot] 🎸 ⚠️ Guitar selection was blank! interactive_data: #{utf8_encode(interactive_data).inspect}"
      selection = 'guitar' # Generic fallback
    end

    update_conversation_attribute('selected_guitar', selection)
    reset_retry_count

    send_text_message("Great choice! You selected #{selection}.")

    # Check if we're in demo mode - if so, stop here
    if @bot_state == 'DEMO_MODE'
      log_info '[Bot] 🎸 In DEMO_MODE - stopping after guitar selection, not sending AR'
      # Stay in DEMO_MODE, don't continue to AR
      return
    end

    # Normal flow: continue to AR introduction
    update_bot_state('AHC2')
    handle_ar_introduction
  end

  def auto_select_guitar(guitar_name)
    update_conversation_attribute('selected_guitar', guitar_name)
  end

  # === AHC States (AR Introduction & Questions) - Phase 2 ===

  def handle_ar_introduction
    # AHC2: Send AR file with introduction message
    get_conversation_attribute('selected_guitar') || 'guitar'
    send_text_message('Just in. We have this cool Stratocaster. Check it out in AR!')
    send_ar_file
    update_bot_state('AHC3')

    # Wait for AR file to fully upload and be delivered before asking question
    # AR file has 2s delay in after_commit + upload time + network latency + device rendering
    # Increased to 15s to ensure AR file is fully visible before question appears
    sleep(15.0)
    handle_ar_first_question
  end

  def handle_ar_first_question
    # AHC3: First AR question
    send_ar_view_question
    update_bot_state('AHD1')
  end

  # Defensive catcher for text input when Quick Reply is expected (AHD1)
  def handle_ar_view_catcher
    log_info '[Bot] 🛡️ handle_ar_view_catcher called - user sent text instead of selecting Quick Reply'
    send_text_message("Please select 'Yes' or 'No' from the options above to let us know if you saw the AR view.")
  end

  def handle_ar_view_response(interactive_data)
    # AHD1: AR view response
    log_info '[Bot] 🎨 handle_ar_view_response called'
    log_info "[Bot] 🎨 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection_value = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                        # NSKeyedArchiver format - check for Yes/No in objects
                        objects = interactive_data['$objects'] || []
                        response = objects.find { |obj| obj.is_a?(String) && obj.match?(/yes|no/i) }
                        log_info "[Bot] 🎨 NSKeyedArchiver AR response: #{utf8_encode(response)}"
                        response&.downcase == 'yes' ? '111' : '222'
                      else
                        # Standard quick reply format - use selectedIndex to determine Yes (0) or No (1)
                        quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                        selected_index = quick_reply_data['selectedIndex']

                        # selectedIndex: 0 = Yes (111), 1 = No (222)
                        identifier = selected_index == 0 ? '111' : '222'
                        log_info "[Bot] 🎨 Standard format AR response - selectedIndex: #{selected_index}, mapped to: #{identifier}"
                        identifier
                      end

    send_text_message('Try tapping on the image to see the AR image of the guitar!') if selection_value == '222' # No - User didn't see AR view

    # Wait a moment before asking the next question
    sleep(2.0)

    # Send the AR placement question
    send_ar_place_question

    update_bot_state('AHE1')
  end

  def handle_ar_place_response(interactive_data)
    # AHE1: AR place response
    log_info '[Bot] 🎨 handle_ar_place_response called'

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection_value = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                        # NSKeyedArchiver format - check for Yes/No in objects
                        objects = interactive_data['$objects'] || []
                        response = objects.find { |obj| obj.is_a?(String) && obj.match?(/yes|no/i) }
                        response&.downcase == 'yes' ? '111' : '222'
                      else
                        # Standard quick reply format - use selectedIndex to determine Yes (0) or No (1)
                        quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                        selected_index = quick_reply_data['selectedIndex']

                        # selectedIndex: 0 = Yes (111), 1 = No (222)
                        selected_index == 0 ? '111' : '222'
                      end

    log_info "[Bot] 🎨 AR place response - selection_value: #{selection_value}"

    send_text_message('Try tapping on the image to see the AR image of the guitar!') if selection_value == '222' # No - they didn't place AR

    # After AR section, proceed to Apple Pay
    update_bot_state('AHE2')
    handle_apple_pay_prompt
    # Defensive catcher for text input when Quick Reply is expected (AHE1)
    def handle_ar_place_catcher
      log_info '[Bot] 🛡️ handle_ar_place_catcher called - user sent text instead of selecting Quick Reply'
      send_text_message("Please select 'Yes' or 'No' from the options above to let us know if you'd like to place the guitar in AR.")
    end
  end

  def handle_apple_pay_prompt
    # AHE2: Send Apple Pay request
    guitar_name = get_conversation_attribute('selected_guitar') || 'guitar'

    result = send_apple_pay_request(guitar_name)

    # Log the result for debugging
    log_info "[Bot] 💳 Apple Pay prompt result: #{result.inspect}"

    # Check for success: result must be a hash with success: true
    if result.is_a?(Hash) && result[:success] == true
      log_info '[Bot] 💳 Apple Pay sent successfully - waiting for user response'
      update_bot_state('AHF1')
    else
      # Log the actual error for debugging
      error_msg = result.is_a?(Hash) && result[:error] ? result[:error] : 'unknown error'
      log_warn "[Bot] 💳 Apple Pay not sent (#{error_msg}) - skipping payment"

      # Skip Apple Pay gracefully without claiming technical difficulties
      send_text_message("For this demo, we'll skip the payment step.")

      # Continue directly to lesson introduction
      reset_retry_count
      update_bot_state('AHF2')
      handle_lesson_introduction
    end
  end

  def handle_apple_pay_catcher
    # AHF1: Apple Pay catcher (retry logic)
    retry_count = increment_retry_count

    if retry_count > 2
      # After 3 attempts, reveal it's a demo
      customer_name = get_conversation_attribute('customer_name') || 'there'
      send_text_message("Just kidding #{customer_name}. We wouldn't process a payment for this demo.")
      reset_retry_count
      update_bot_state('AHF2')
      handle_lesson_introduction
    else
      # Still waiting for Apple Pay response
      send_text_message('Waiting for Apple Pay response...')
    end
  end

  def handle_apple_pay_response(interactive_data)
    # Handle Apple Pay completion
    payment_state = interactive_data.dig('data', 'payment', 'state')

    log_info '[Bot] 💳 handle_apple_pay_response called'
    log_info "[Bot] 💳 Current bot_state: #{@bot_state}"
    log_info "[Bot] 💳 Apple Pay response - payment_state: #{payment_state}"

    if payment_state == 'paid'
      customer_name = get_conversation_attribute('customer_name') || 'there'
      send_text_message("Just kidding #{customer_name}. We wouldn't process a payment for this demo.")
    else
      send_text_message('Payment was not completed. Let\'s continue with the demo.')
    end

    # Check if we're in demo mode - if so, stop here
    if @bot_state == 'DEMO_MODE'
      log_info '[Bot] 💳 ✅ In DEMO_MODE - stopping after Apple Pay response'
      send_text_message("Type 'startover' to restart the conversation.")
      return
    end

    # Normal flow: continue to lesson introduction
    log_info "[Bot] 💳 Not in DEMO_MODE (state: #{@bot_state}) - continuing to lesson introduction"
    reset_retry_count
    update_bot_state('AHF2')
    handle_lesson_introduction
  end

  def handle_skip_payment(_interactive_data = nil)
    # Handle skip payment request - can be called from quick reply or keyword
    log_info '[Bot] 💳 Skip payment requested'

    # Only allow skip if we're in a payment-related state
    unless %w[AHF1 AHF1_skip AHE2].include?(@bot_state)
      send_text_message("The 'skip' command is only available during payment processing.")
      return
    end

    # Check if this is a quick reply response (has interactive_data)
    if _interactive_data.present?
      # Extract selected option - handle both standard format and NSKeyedArchiver
      selection = if _interactive_data['$archiver'] == 'NSKeyedArchiver'
                    # NSKeyedArchiver format - extract title from $objects array
                    objects = _interactive_data['$objects'] || []
                    objects.find { |obj| obj.is_a?(String) && obj.match?(/skip|try|retry/i) }
                  else
                    # Standard quick reply format
                    quick_reply_data = _interactive_data.dig('data', 'quick-reply') || {}
                    selected_index = quick_reply_data['selectedIndex']
                    items = quick_reply_data['items'] || []

                    items[selected_index]&.fetch('title', nil) if selected_index
                  end

      log_info "[Bot] 💳 Skip payment selection: #{utf8_encode(selection)}"

      # If user selected "Try Again", retry payment
      if selection&.match?(/try|retry/i)
        send_text_message('Retrying payment...')
        handle_apple_pay_prompt
        return
      end
    end

    # Skip payment and continue
    send_text_message('No problem! Skipping payment and continuing with the demo.')
    reset_retry_count
    update_bot_state('AHF2')
    handle_lesson_introduction
  end

  # === Phase 3: Lesson Booking, Time Picker, Rich Links ===

  # MVP: Hardcoded location database (6 locations)
  LOCATION_DATABASE = {
    # California
    '95014' => { name: 'Apple Park Visitor Center', latitude: 37.332863, longitude: -122.0053739, timezone_offset: '-0800' },
    '94102' => { name: 'Apple Union Square', latitude: 37.788493, longitude: -122.407074, timezone_offset: '-0800' },
    # New York
    '10019' => { name: 'Apple Fifth Avenue', latitude: 40.763829, longitude: -73.972699, timezone_offset: '-0500' },
    '10001' => { name: 'Apple World Trade Center', latitude: 40.711622, longitude: -74.011765, timezone_offset: '-0500' },
    # Texas
    '78701' => { name: 'Apple Domain Northside', latitude: 30.398798, longitude: -97.720589, timezone_offset: '-0600' },
    # Illinois
    '60611' => { name: 'Apple Michigan Avenue', latitude: 41.892639, longitude: -87.623734, timezone_offset: '-0600' }
  }.freeze

  def handle_lesson_introduction
    # AHF2: Introduce lesson booking
    guitar = get_conversation_attribute('selected_guitar') || 'guitar'
    send_text_message("However, let's schedule a lesson with your new #{guitar}.")

    update_bot_state('AHF3')
    handle_location_request
  end

  def handle_location_request
    # AHF3: Ask for location
    intent = get_conversation_attribute('region')

    if intent == 'Traveling'
      send_text_message('We can find a few locations near your travel destination, just provide us with the zipcode.')
    else
      send_text_message('We can find the closest location for you, just message us your zipcode and city. Where are you?')
    end

    update_bot_state('AHG1')
  end

  def handle_location_response
    # AHG1: Process location input (zipcode or Apple Maps link)
    user_message = @message.content.strip

    # Initialize Apple Maps service
    maps_service = AppleMessagesForBusiness::AppleMapsService.new

    # Extract coordinates from input
    coordinates = nil

    # Check if Apple Maps link
    if user_message.include?('maps.apple.com')
      coordinates = maps_service.extract_coordinates_from_url(user_message)
      if coordinates
        log_info "[Bot] 📍 Extracted coordinates from Apple Maps link: #{utf8_encode(coordinates).inspect}"
      else
        log_warn "[Bot] ⚠️ Failed to extract coordinates from Apple Maps URL: #{utf8_encode(user_message)}"
      end
    end

    # If not a maps link or extraction failed, try geocoding as zipcode/address
    if coordinates.nil?
      log_info "[Bot] 📍 Attempting geocoding for: '#{utf8_encode(user_message)}'"
      geocode_result = maps_service.geocode(user_message)

      if geocode_result
        coordinates = {
          latitude: geocode_result[:latitude],
          longitude: geocode_result[:longitude]
        }
        log_info "[Bot] 📍 Geocoded '#{utf8_encode(user_message)}' to: #{utf8_encode(coordinates).inspect}"
      else
        # Geocoding failed - provide helpful message based on region
        region = get_conversation_attribute('region')
        log_warn "[Bot] ⚠️ Geocoding failed for: '#{utf8_encode(user_message)}'"

        if region == 'EMEA'
          send_text_message("I couldn't find that postal code. Please try again with your city and country (e.g., '#{user_message} Paris, France' or '78120 Rambouillet, France').")
        else
          send_text_message("I couldn't find that location. Please try again with more details like your city or full address.")
        end

        # Stay in same state to wait for better input
        return
      end
    end

    # If we have coordinates, search for nearby Apple Stores
    if coordinates
      log_info "[Bot] 🔍 Searching for Apple Stores near: #{utf8_encode(coordinates).inspect}"
      stores = maps_service.search_nearby(
        coordinates[:latitude],
        coordinates[:longitude],
        'Apple Store',
        radius: 10_000 # 10 km - reduced from 20 km to filter closer stores
      )

      if stores.present?
        log_info "[Bot] 🏪 Found #{stores.length} Apple Stores nearby"

        # Route based on number of stores found
        case stores.length
        when 1
          # Single store: Send as Apple Maps rich link and proceed to time picker
          send_single_store_rich_link(stores.first, coordinates)
        when 2..5
          # 2-5 stores: Send as quick reply buttons
          send_store_quick_reply(stores, coordinates)
          update_bot_state('AHG2') # Wait for selection
        else
          # 6+ stores: Send as list picker
          send_store_selection_list_picker(stores, coordinates)
          update_bot_state('AHG2') # Wait for selection
        end

        reset_retry_count
        return
      else
        log_warn "[Bot] ⚠️ Search returned 0 stores near: #{utf8_encode(coordinates).inspect}"
      end
    else
      log_warn '[Bot] ⚠️ No coordinates available after URL parsing and geocoding'
    end

    # Fallback: No coordinates or no stores found
    log_warn '[Bot] ⚠️ Could not find Apple Stores, falling back to Apple Park'
    location = LOCATION_DATABASE['95014']
    send_text_message('We were unable to locate your nearest Apple Store, so here are the available times at Apple Park.')
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
    reset_retry_count
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] ❌ Error in handle_location_response: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))

    # Fallback on error
    location = LOCATION_DATABASE['95014']
    send_text_message('We encountered an error finding stores nearby. Here are the available times at Apple Park.')
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
    reset_retry_count
  end

  def handle_time_picker_catcher
    # AHH1: Retry logic for time picker selection
    retry_count = increment_retry_count

    case retry_count
    when 1
      send_text_message('Looks like we\'re waiting for you to select a time from the menu above.')
    when 2
      send_text_message('You may set up a lesson at Apple Park')
      location = LOCATION_DATABASE['95014']
      send_lesson_time_picker(location)
    when 3
      send_text_message('If you find yourself stuck, you may have an overview with the keyword "Menu".')
    when 4
      send_text_message('You must be a shredding pro, we can skip scheduling a lesson.')
      reset_retry_count
      update_bot_state('AHH2')
      handle_continue_prompt
    else
      send_text_message('Still waiting for your time selection, or type "Menu" for help.')
    end
  end

  def handle_time_picker_response(_interactive_data)
    log_info '[Bot] 🕐 handle_time_picker_response called'
    log_info "[Bot] 🕐 interactive_data keys: #{utf8_encode(_interactive_data.keys).inspect}"

    # Idempotency guard: prevent processing the same time picker response twice
    selection_data = _interactive_data['ldtext'] || _interactive_data.dig('data', 'event', 'timeslots')&.to_json || 'unknown'
    selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
    selection_key = "time_picker_response:#{selection_hash}"

    if Redis::Alfred.get(selection_key).present?
      log_info "[Bot] 🕐 Time picker response already processed (hash: #{selection_hash}), skipping"
      return
    end

    # Mark as processed (expires after 2 minutes)
    Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
    log_info "[Bot] 🕐 Time picker response marked as processed (hash: #{selection_hash})"

    # Handle both direct format and NSKeyedArchiver format
    selected_time = if _interactive_data['data'].present?
                      # Direct interactiveData format - extract from data structure
                      timeslots = _interactive_data.dig('data', 'event', 'timeslots')
                      log_info "[Bot] 🕐 Direct format - timeslots: #{utf8_encode(timeslots).inspect}"
                      timeslots&.first
                    else
                      # NSKeyedArchiver format - extract from ldtext
                      time_string = _interactive_data['ldtext']
                      log_info "[Bot] 🕐 NSKeyedArchiver format - extracted time: #{utf8_encode(time_string)}"

                      if time_string.present?
                        # Create a minimal timeslot structure with the selected time
                        {
                          'startTime' => time_string,
                          'formatted_time' => time_string
                        }
                      end
                    end

    log_info "[Bot] 🕐 Selected time: #{utf8_encode(selected_time).inspect}"

    if selected_time
      # Save the selected time data
      update_conversation_attribute('selected_timeslot', selected_time)
      reset_retry_count

      # Check if we're in demo mode - if so, stop here
      if @bot_state == 'DEMO_MODE'
        log_info '[Bot] 🕐 In DEMO_MODE - stopping after time picker response'
        send_text_message("Great! You selected #{selected_time['formatted_time'] || selected_time['startTime']}.")
        send_text_message("Type 'startover' to restart the conversation.")
        return
      end

      # Normal flow: continue to continue prompt
      update_bot_state('AHH2')
      handle_continue_prompt
    else
      # Invalid response, retry
      log_warn '[Bot] 🕐 No timeslot found in time picker response'
      handle_time_picker_catcher
    end
  end

  def handle_continue_prompt
    # AHH2: Ask if user wants to continue
    send_text_message('Thank you for your co-operation, you\'re all set to learn to shred. 🤘')

    send_quick_reply(
      title: 'Shall we continue?',
      request_id: 'qr_continue',
      message: 'Shall we continue?',
      items: [
        { title: 'Yes', value: 'Yes' },
        { title: 'No', value: 'No' }
      ]
    )

    update_bot_state('AHI1')
  end

  def handle_continue_response(_interactive_data)
    # AHI1: Route based on continue response
    log_info '[Bot] 🎯 handle_continue_response called'

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection_identifier = if _interactive_data['$archiver'] == 'NSKeyedArchiver'
                             # NSKeyedArchiver format - check for Yes/No in objects
                             objects = _interactive_data['$objects'] || []
                             response = objects.find { |obj| obj.is_a?(String) && obj.match?(/yes|no/i) }
                             response&.downcase == 'yes' ? '111' : '222'
                           else
                             # Standard quick reply format - use selectedIndex to determine Yes (0) or No (1)
                             quick_reply_data = _interactive_data.dig('data', 'quick-reply') || {}
                             selected_index = quick_reply_data['selectedIndex']

                             # selectedIndex: 0 = Yes (111), 1 = No (222)
                             selected_index == 0 ? '111' : '222'
                           end

    if selection_identifier == '222' # No
      # Skip rich links and photos, go directly to learn more prompt
      update_bot_state('AHJ4')
      handle_learn_more_prompt
    else
      # Continue to photo question (skip rich link until after photo response)
      update_bot_state('AHI3')
      handle_photo_intro
    end
  end

  def handle_rich_link_display
    # AHI2: Send rich link (called after photo response)
    send_text_message('There\'s so much more you can do like sharing beautiful links to your website:')
    send_apple_messages_rich_link
  end

  def handle_photo_intro
    # AHI3: Introduction to photos
    send_text_message('Earlier we sent you a photo.')

    update_bot_state('AHI4')
    handle_photo_request
  end

  def handle_photo_request
    # AHI4: Request photo from user
    first_name = get_conversation_attribute('customer_name') || 'there'

    send_quick_reply(
      title: 'Will you share a picture?',
      request_id: 'qr_photo',
      message: "You can send us one too!!! #{first_name} will you share a picture of your favorite food or place to eat?",
      items: [
        { title: 'Yes', value: 'Yes' },
        { title: 'No', value: 'No' }
      ]
    )

    update_bot_state('AHJ1')
  end

  def handle_rich_links
    # Deprecated - replaced by handle_rich_link_display
    send_text_message('Or... just send a photo anytime')
    update_bot_state('AHJ1')
  end

  # === AHJ States (Photo Response & Documents) ===

  def handle_photo_response(interactive_data)
    # AHJ1: Handle photo quick reply response
    log_info '[Bot] 📷 handle_photo_response called'

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                  # NSKeyedArchiver format - extract title from $objects array
                  objects = interactive_data['$objects'] || []
                  objects.find { |obj| obj.is_a?(String) && obj.match?(/yes|no/i) }
                else
                  # Standard quick reply format
                  quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                  selected_index = quick_reply_data['selectedIndex']
                  items = quick_reply_data['items'] || []

                  items[selected_index]&.fetch('title', nil) if selected_index
                end

    if selection&.match?(/yes/i)
      # User said Yes - wait for them to send a photo
      send_text_message('Awesome! We will hang tight while you send us your fav.')
      # Stay in AHJ1 state - attachment handler will progress to AHJ2 when photo is received
    else
      # User said No - skip photo and ask if they want to learn more
      send_text_message('No problem!')
      update_bot_state('AHJ4')
      handle_learn_more_prompt
    end
  end

  def handle_documents_intro
    # AHJ2: Send metrics.numbers
    send_text_message('In Messages for Business, we can also share documents like these forms.')
    send_document('metrics.numbers')

    # Check if we're in demo mode - if so, send PDF and stop
    if @bot_state == 'DEMO_MODE'
      send_document('document.pdf')

      # Wait for documents to be delivered before sending restart message
      sleep(2.0)

      log_info '[Bot] 📄 In DEMO_MODE - stopping after documents sent'
      #send_text_message("Type 'startover' to restart the conversation.")
      return
    end

    # Normal flow: continue to next state
    update_bot_state('AHJ3')
    handle_pdf_document
  end

  def handle_pdf_document
    # AHJ3: Send document.pdf
    send_document('document.pdf')
    update_bot_state('AHJ4')
    handle_learn_more_prompt
  end

  def handle_learn_more_prompt
    # AHJ4: Ask about learning more
    customer_name = @conversation.custom_attributes&.dig('customer_name') || 'there'

    send_quick_reply(
      title: 'Learn More?',
      request_id: 'qr_learn_more',
      message: "#{customer_name}, would you like to learn more about Messages for Business?",
      items: [
        { title: 'Yes', value: 'yes' },
        { title: 'No', value: 'no' }
      ]
    )

    update_bot_state('AHK0')
  end

  # === AHK States (Summary & Final Rich Link) ===

  def handle_summary
    # AHK1: Summary list picker
    send_summary_list_picker
    update_bot_state('AHK2')

    # Wait for list picker to be delivered before sending final message
    # List picker needs time to be sent and rendered on device
    sleep(3.0)
    handle_final_message
  end

  def handle_final_message
    # AHK2: Final encouragement message
    send_text_message('A great first step will be to visit our Register site to get started.')
    update_bot_state('AHK3')
    handle_register_rich_link
  end

  def handle_register_rich_link
    # AHK3: Send register rich link and reset flow
    send_rich_link(
      url: 'https://register.apple.com/business-chat',
      image_asset: 'heroImage.png',
      title: 'Apple Messages for Business'
    )
    send_text_message('We will get back to you soon 😀')

    # Reset flow to welcome
    update_bot_state('AH-restart')
    reset_retry_count
  end

  # Attachment handler
  def handle_received_attachment
    # Check if attachment is received during AHJ states
    return unless @bot_state.start_with?('AHI', 'AHJ')

    log_info "[Bot] 📎 handle_received_attachment called - bot_state: #{@bot_state}"
    log_info "[Bot] 📎 message.content_type: #{@message.content_type}"
    log_info "[Bot] 📎 attachments count: #{@message.attachments.count}"

    content_type = @message.content_type

    # Check if ANY attachment is an image (Apple Messages might set content_type to 'text' or 'incoming')
    has_image_attachment = @message.attachments.any? do |attachment|
      file_content_type = attachment.file&.content_type
      log_info "[Bot] 📎 attachment content_type: #{file_content_type}"
      file_content_type&.start_with?('image/')
    end

    if content_type&.start_with?('image/') || has_image_attachment
      log_info '[Bot] 📎 Image attachment detected!'
      send_text_message('Awesome photo! #photooftheday #instadaily')
      update_bot_state('AHJ4')
      handle_learn_more_prompt
    elsif content_type == 'application/vnd.apple.numbers'
      send_text_message('Thank you for the spreadsheet.')
    else
      log_info "[Bot] 📎 No image found - content_type: #{content_type}, has_image: #{has_image_attachment}"
    end
  end

  # === Keyword Handlers ===

  def handle_menu
    # send_text_message('🎸 Acoustic House Bot Menu')
    send_menu_list_picker
    # Set demo mode state to prevent flow continuation after menu selection
    update_bot_state('DEMO_MODE')
  end

  def handle_start_over
    reset_to_welcome
    send_text_message('Restarting conversation...')
    handle_welcome
  end

  def handle_stop
    update_bot_state('STOPPED')
    send_text_message("Bot stopped. Type 'startover' to restart.")
  end

  def handle_schedule_lesson
    # Handle schedule/lesson keyword - replay from location request
    log_info '[Bot] 📅 Schedule lesson requested via keyword'

    # Reset any retry counts
    reset_retry_count

    # Ask for location again
    guitar = get_conversation_attribute('selected_guitar') || 'guitar'
    send_text_message("Let's schedule a lesson with your #{guitar}!")
    handle_location_request
  end

  def handle_list_picker_demo
    # Demo mode: just show the list picker, don't continue flow
    send_text_message('Here are some amazing guitars:')
    send_guitar_list_picker
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_time_picker_demo
    send_text_message('Time picker demo coming soon!')
  end

  def handle_apple_pay_demo
    # Demo mode: send Apple Pay request with demo item
    send_text_message('Here\'s an Apple Pay payment request:')

    result = send_apple_pay_request('Demo Guitar - Fender Stratocaster')

    # Log the result for debugging
    log_info "[Bot] 💳 Apple Pay demo result: #{result.inspect}"

    # Only send error message if payment explicitly failed
    # Check for success: result must be a hash with success: true
    if result.is_a?(Hash) && result[:success] == true
      # Payment sent successfully - do nothing more
      log_info '[Bot] 💳 Apple Pay demo sent successfully - no error message'
    else
      # Payment failed - show error
      error_msg = result.is_a?(Hash) && result[:error] ? result[:error] : 'unknown error'
      log_warn "[Bot] 💳 Apple Pay demo failed (#{error_msg}) - showing error message"
      send_text_message('Apple Pay is currently unavailable. Please try again later.')
    end

    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_form_demo
    # Demo mode: just show the form, don't continue flow
    send_text_message('Here\'s our guitar information form:')
    send_guitar_info_form
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_ar_demo
    # Demo mode: just show AR content, don't continue flow
    send_text_message('Check out our AR experience:')
    send_ar_file
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_large_form_demo
    # Demo mode: send large content form (template 343)
    send_text_message('Here\'s a form with large content:')
    send_large_content_form
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_menu_selection(interactive_data)
    log_info '[Bot] 📋 handle_menu_selection called'
    log_info "[Bot] 📋 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"
    log_info "[Bot] 📋 Has ldtext? #{interactive_data['ldtext'].present?}"
    log_info "[Bot] 📋 Has $archiver? #{interactive_data['$archiver'].present?}"
    log_info "[Bot] 📋 Has data.listPicker? #{interactive_data.dig('data', 'listPicker').present?}"

    # Idempotency guard: prevent processing the same menu selection twice
    # Use conversation ID + timestamp + selection data as the unique key
    # This prevents duplicate processing even if multiple message objects are created
    selection_data = interactive_data['ldtext'] || interactive_data.dig('data', 'listPicker', 'sections')&.to_json || 'unknown'
    selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
    selection_key = "menu_selection:#{selection_hash}"

    if Redis::Alfred.get(selection_key).present?
      log_info "[Bot] 📋 Menu selection already processed (hash: #{selection_hash}), skipping"
      return
    end

    # Mark as processed (expires after 2 minutes - enough time to prevent duplicates but not too long)
    Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
    log_info "[Bot] 📋 Menu selection marked as processed (hash: #{selection_hash})"

    # Extract selection from interactive data
    # The selection is in the listPicker sections under data
    selection_identifier = nil
    selected_item_title = nil  # Track the title for remapping if needed

    if interactive_data['ldtext'].present?
      # Resolved NSKeyedArchiver/IDR format - selection is in ldtext
      item_title = interactive_data['ldtext']
      log_info "[Bot] 📋 IDR format menu selection (ldtext): #{utf8_encode(item_title)}"
      log_info "[Bot] 📋 ldtext class: #{item_title.class}, length: #{item_title.length}, bytes: #{item_title.bytes.inspect[0..100]}"

      # Map menu item titles to identifiers (case-insensitive, flexible matching)
      menu_map = {
        '1. Introduction with Intent ID' => '1',
        '2. Send a List Picker' => '2',
        '3. Receive an AR Image' => '3',
        '4. Apple Pay' => '4',
        '5. Schedule a Guitar Lesson' => '5',
        '6. Fill in a Form' => '6',
        '7. Send an Image' => '7',
        '8. Send Documents' => '8',
        '9. Large Form' => '9',
        '10. Authentication' => '10',
        '11. iMessage App' => '11',
        '12. Apple Wallet' => '12',
        '13. Rich Link Locator' => '13'
      }

      log_info '[Bot] 📋 Attempting exact match against menu_map keys...'
      # Try exact match first
      selection_identifier = menu_map[item_title]
      log_info "[Bot] 📋 Exact match result: #{selection_identifier.inspect}"

      # If no exact match, try case-insensitive match
      if selection_identifier.nil?
        log_info '[Bot] 📋 No exact match, trying case-insensitive...'
        menu_map.each do |key, value|
          next unless key.downcase == item_title.downcase

          selection_identifier = value
          log_info "[Bot] 📋 Found case-insensitive match: '#{utf8_encode(key)}' => '#{value}'"
          break
        end
      end

      # If still no match, try partial match (for cases where template has slight variations)
      if selection_identifier.nil?
        log_info '[Bot] 📋 No case-insensitive match, trying partial match...'
        menu_map.each do |key, value|
          # Extract just the menu text after the number (e.g., "Fill in a Form" from "6. Fill in a Form")
          key_text = key.sub(/^\d+\.\s*/, '')
          item_text = item_title.sub(/^\d+\.\s*/, '')

          log_info "[Bot] 📋 Comparing key_text='#{utf8_encode(key_text)}' with item_text='#{utf8_encode(item_text)}'"

          next unless key_text.downcase == item_text.downcase

          selection_identifier = value
          log_info "[Bot] 📋 Found partial match: '#{utf8_encode(key_text)}' matches '#{utf8_encode(item_text)}' => '#{value}'"
          break
        end
      end

      log_info "[Bot] 📋 After menu_map lookup, selection_identifier: #{selection_identifier.inspect}"
    elsif interactive_data['$archiver'] == 'NSKeyedArchiver'
      # Raw NSKeyedArchiver format - extract from $objects array
      objects = interactive_data['$objects'] || []
      # Find the identifier (should be a number string)
      selection_identifier = objects.find { |obj| obj.is_a?(String) && obj.match?(/^\d+$/) }
    else
      # Standard format - extract from listPicker sections
      data = interactive_data['data'] || {}
      list_picker = data['listPicker'] || {}
      sections = list_picker['sections'] || []

      # Find the selected item across all sections
      sections.each do |section|
        items = section['items'] || []
        selected_item = items.find { |item| item['identifier'].present? }
        next unless selected_item

        # Capture title for potential remapping
        selected_item_title = selected_item['title']
        # Extract the identifier (may be "option_2" or "176347360869701")
        selection_identifier = selected_item['identifier'].to_s
        log_info "[Bot] 📋 Found selected item: #{utf8_encode(selected_item_title)} (identifier: #{selection_identifier})"
        break
      end
    end

    log_info "[Bot] 📋 Final selected menu identifier: #{selection_identifier.inspect}"

    # Verify selection is valid before routing
    if selection_identifier.nil? || selection_identifier.empty?
      log_warn '[Bot] ❌ Menu selection is nil or empty!'
      log_warn "[Bot] 📋 interactive_data structure: #{utf8_encode(interactive_data.keys).inspect}"
      log_warn "[Bot] 📋 Has ldtext: #{interactive_data['ldtext'].present?} (value: #{utf8_encode(interactive_data['ldtext']).inspect})"
      log_warn "[Bot] 📋 Has $archiver: #{interactive_data['$archiver'].present?}"
      log_warn "[Bot] 📋 Has data.listPicker: #{interactive_data.dig('data', 'listPicker').present?}"
      log_warn "[Bot] 📋 Full interactive_data: #{utf8_encode(interactive_data).inspect}"
      send_text_message('Invalid selection. Type \'menu\' to try again.')
      update_bot_state('DEMO_MODE')
      return
    end

    # If we got a large template-generated identifier, try to extract ldtext instead
    unless /^\d{1,2}$/.match?(selection_identifier)  # Not a 1-2 digit number
      log_warn "[Bot] 📋 Got non-standard identifier: #{selection_identifier}, attempting title mapping..."

      # Get the title from ldtext or the captured title
      item_title = interactive_data['ldtext'] || selected_item_title

      if item_title.present?
        log_info "[Bot] 📋 Found title for mapping: #{utf8_encode(item_title)}"

        # Map title to identifier
        title_to_id = {
          '1. Introduction with Intent ID' => '1',
          '2. Send a List Picker' => '2',
          '3. Receive an AR Image' => '3',
          '4. Apple Pay' => '4',
          '5. Schedule a Guitar Lesson' => '5',
          '6. Fill in a Form' => '6',
          '7. Send an Image' => '7',
          '8. Send Documents' => '8',
          '9. Large Form' => '9',
          '10. Authentication' => '10',
          '11. iMessage App' => '11',
          '12. Apple Wallet' => '12',
          '13. Rich Link Locator' => '13'
        }

        # Try exact match
        mapped_id = title_to_id[item_title]

        # Try case-insensitive
        if mapped_id.nil?
          title_to_id.each do |key, value|
            if key.downcase == item_title.downcase
              mapped_id = value
              break
            end
          end
        end

        # Try partial match (strip number prefix)
        if mapped_id.nil?
          item_text = item_title.sub(/^\d+\.\s*/, '')
          title_to_id.each do |key, value|
            key_text = key.sub(/^\d+\.\s*/, '')
            next unless key_text.downcase == item_text.downcase

            mapped_id = value
            log_info "[Bot] 📋 Mapped via partial match: '#{item_text}' => '#{value}'"
            break
          end
        end

        if mapped_id
          log_info "[Bot] 📋 Remapped identifier from #{selection_identifier} to #{mapped_id}"
          selection_identifier = mapped_id
        else
          log_warn "[Bot] 📋 Could not map title '#{utf8_encode(item_title)}' to known identifier"
        end
      else
        log_warn '[Bot] 📋 No title available for remapping (ldtext and selected_item_title both empty)'
      end
    end

    # Route to appropriate handler based on selection
    log_info "[Bot] 📋 Routing menu selection '#{selection_identifier}' to handler"

    case selection_identifier
    when '1'
      # 1. Introduction with Intent ID - restart flow
      log_info '[Bot] 📋 Menu: Introduction with Intent ID'
      send_text_message('Let\'s start from the beginning!')
      handle_start_over
    when '2'
      # 2. Send a List Picker
      log_info '[Bot] 📋 Menu: Send a List Picker'
      handle_list_picker_demo
    when '3'
      # 3. Receive an AR Image
      log_info '[Bot] 📋 Menu: Receive an AR Image'
      handle_ar_demo
    when '4'
      # 4. Apple Pay
      log_info '[Bot] 📋 Menu: Apple Pay'
      handle_apple_pay_demo
    when '5'
      # 5. Schedule a Guitar Lesson
      log_info '[Bot] 📋 Menu: Schedule a Guitar Lesson'
      handle_schedule_lesson
    when '6'
      # 6. Fill in a Form
      log_info '[Bot] 📋 Menu: Fill in a Form'
      handle_form_demo
    when '7'
      # 7. Send an Image
      log_info '[Bot] 📋 Menu: Send an Image'
      send_text_message("Photo sharing demo:\n\nYou can send us a photo anytime! Just attach it to your message.")
      update_bot_state('DEMO_MODE')
    when '8'
      # 8. Send Documents
      log_info '[Bot] 📋 Menu: Send Documents'
      send_text_message('Document sharing demo:')
      handle_documents_intro
    when '9'
      # 9. Large Form
      log_info '[Bot] 📋 Menu: Large Form'
      handle_large_form_demo
    when '10'
      # 10. Authentication - TODO: Implement authentication demo
      log_info '[Bot] 📋 Menu: Authentication (not implemented)'
      send_text_message('🔐 Authentication Demo')
      send_text_message('This feature demonstrates OAuth authentication flow with Apple Messages for Business.')
      send_text_message('Implementation coming soon! Type \'menu\' to see other options.')
      update_bot_state('DEMO_MODE')
    when '11'
      # 11. iMessage App - TODO: Implement custom iMessage app demo
      log_info '[Bot] 📋 Menu: iMessage App (not implemented)'
      send_text_message('📱 iMessage App Demo')
      send_text_message('This feature demonstrates custom iMessage app extensions.')
      send_text_message('Implementation coming soon! Type \'menu\' to see other options.')
      update_bot_state('DEMO_MODE')
    when '12'
      # 12. Apple Wallet
      log_info '[Bot] 📋 Menu: Apple Wallet (not implemented)'
      send_text_message('Apple Wallet demo is not yet implemented.')
      send_text_message('Type \'menu\' to see other options.')
      update_bot_state('DEMO_MODE')
    when '13'
      # 13. Rich Link Locator
      log_info '[Bot] 📋 Menu: Rich Link Locator'
      send_text_message('Here\'s a rich link demo:')
      send_apple_messages_rich_link
      update_bot_state('DEMO_MODE')
    else
      log_warn "[Bot] ❌ Unknown menu selection identifier: '#{selection_identifier}'"
      log_warn "[Bot] ❌ This should be a number 1-13, got: #{selection_identifier.class} with value #{utf8_encode(selection_identifier).inspect}"
      send_text_message('Invalid selection. Type \'menu\' to try again.')
      update_bot_state('DEMO_MODE')
    end
  end

  def handle_learn_more_response(interactive_data)
    log_info '[Bot] 📚 handle_learn_more_response called'

    # Extract selected option - handle both standard format and NSKeyedArchiver
    selection = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                  # NSKeyedArchiver format - extract title from $objects array
                  objects = interactive_data['$objects'] || []
                  objects.find { |obj| obj.is_a?(String) && obj.match?(/yes|no/i) }
                else
                  # Standard quick reply format
                  quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                  selected_index = quick_reply_data['selectedIndex']
                  items = quick_reply_data['items'] || []

                  items[selected_index]&.fetch('title', nil) if selected_index
                end

    if selection&.match?(/yes/i)
      # User wants to learn more - show documents and rich link
      send_text_message('Let me show you what else we can do.')
      sleep(1.0)

      # Send documents
      send_text_message('In Messages for Business, we can also share documents like these forms.')
      send_document('metrics.numbers')
      send_document('document.pdf')

      # Wait longer for documents to be fully sent and delivered (6 seconds)
      # Documents need time to: upload to ActiveStorage → send to Apple MSP → deliver to device
      sleep(6.0)

      # Then show rich link (handle_rich_link_display sends its own intro message)
      handle_rich_link_display
      sleep(1.0)
      send_text_message('Please connect with your Apple rep for more information.')
    else
      # User doesn't want to learn more - skip to summary
      send_text_message('No problem!')
    end

    # Go to summary at the end
    update_bot_state('AHK1')
    handle_summary
  end

  # === Helper Methods ===

  def send_text_message(content)
    with_typing_indicator do
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: content
        )
      ).perform
    end
  end

  def send_quick_reply(title:, request_id:, items:, message: nil)
    log_info "[Bot] 📤 Sending quick reply: #{utf8_encode(title)} (request_id: #{request_id})"
    log_info "[Bot] 📤 Called from: #{caller[0..3].join("\n")}"

    # If message parameter is provided, send it as a text message first
    if message.present?
      log_info "[Bot] 📤 Sending text message before quick reply: #{utf8_encode(message)}"
      send_text_message(message)
    end

    with_typing_indicator do
      # Create outgoing message with quick reply content
      # NOTE: SendReplyJob will automatically send this to Apple MSP via after_create callback
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: title,
          content_type: 'apple_quick_reply',
          content_attributes: {
            'request_identifier' => request_id,
            'summary_text' => title,
            'received_title' => title,
            'reply_title' => 'Selected: ${item.title}',
            'items' => items.map do |item|
              {
                'title' => item[:title],
                'identifier' => request_id
              }
            end
          }
        )
      ).perform
    end

    # Message will be automatically sent by SendReplyJob (after_create callback)
    # No need to manually call SendQuickReplyService
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send quick reply: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_guitar_list_picker
    # Get guitar list picker template by ID
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 371
    )

    unless template
      Rails.logger.error utf8_encode('[Bot] Guitar List Picker template (ID: 371) not found')
      send_text_message('Guitar selection temporarily unavailable.')
      return
    end

    log_info "[Bot] Sending Guitar List Picker (ID: 371, Name: #{utf8_encode(template.name)})"

    # Use TemplateFacade with image loading (latest implementation)
    facade = AppleMessagesForBusiness::TemplateFacade.new(template)

    # Load data WITH images using the new method (replaces manual fetch_and_encode_images)
    data = facade.load_data_with_images('list_picker')

    log_info "[Bot] 🎸 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"
    log_info "[Bot] 🎸 Loaded template with #{data['images']&.length || 0} images"

    # All data is in snake_case format with images included
    sections = data['sections'] || []
    images = data['images'] || []
    received_image_id = data['received_image_identifier']
    reply_image_id = data['reply_image_identifier']
    received_title = data['received_title']
    received_subtitle = data['received_subtitle']
    received_style = data['received_style']
    reply_title = data['reply_title']
    reply_subtitle = data['reply_subtitle']
    reply_style = data['reply_style']

    if sections.blank?
      Rails.logger.error utf8_encode('[Bot] Guitar List Picker template has no sections')
      send_text_message('Guitar selection temporarily unavailable.')
      return
    end

    # Build content attributes with all components (images already loaded by facade)
    content_attrs = {
      'sections' => sections,
      'images' => images,
      'request_identifier' => 'lp_guitar_0319'
    }

    # Add received_message fields
    if received_title.present?
      content_attrs['received_title'] = received_title
      content_attrs['received_subtitle'] = received_subtitle
      content_attrs['received_image_identifier'] = received_image_id
      content_attrs['received_style'] = received_style
    end

    # Add reply_message fields
    if reply_title.present?
      content_attrs['reply_title'] = reply_title
      content_attrs['reply_subtitle'] = reply_subtitle
      content_attrs['reply_image_identifier'] = reply_image_id
      content_attrs['reply_style'] = reply_style
    end

    # Create outgoing message with list picker content including images
    # NOTE: Message will be automatically sent via after_commit callback
    # which routes to SendListPickerService based on content_type
    Messages::MessageBuilder.new(
      message_sender,
      @conversation,
      bot_message_params(
        message_type: :outgoing,
        content: 'Select a guitar',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      )
    ).perform

    log_info '[Bot] Guitar List Picker sent successfully'
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send guitar list picker: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def fetch_and_encode_images(identifiers)
    return [] if identifiers.empty?

    # Use ImageFetchService with three-tier fallback
    # Bot doesn't use embedded images - all images come from storage
    images = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      embedded_images: [] # Bot doesn't use embedded images
    ).fetch_and_encode(identifiers)

    log_info "[Bot] 🖼️ Looking for images with identifiers: #{identifiers.inspect}"
    log_info "[Bot] 🖼️ Found #{images.count}/#{identifiers.count} images"

    # Convert from ImageFetchService format (symbol keys) to SendListPickerService format (string keys)
    images.map do |image|
      {
        'identifier' => image[:identifier],
        'data' => image[:data],
        'description' => image[:description] || ''
      }
    end
  end

  def send_guitar_info_form
    # Use the specific form template by ID
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 356
    )

    unless template
      Rails.logger.error utf8_encode('[Bot] Guitar Info Form template (ID: 356) not found - falling back to guitar list')
      # Fallback: skip to guitar list if form template doesn't exist
      update_bot_state('AHB3')
      handle_guitar_list_prompt
      return
    end

    log_info "[Bot] Sending Guitar Info Form (ID: 356, Name: #{utf8_encode(template.name)})"

    # Use BotRendererService to properly render the template
    renderer = Templates::BotRendererService.new(
      template_id: 356,
      parameters: {},
      channel_type: 'apple_messages_for_business'
    )

    rendered = renderer.render_for_bot

    # Add request_identifier for proper routing
    rendered[:content_attributes]['request_identifier'] = 'form_0343' if rendered[:content_attributes]['request_identifier'].blank?

    # Create outgoing message with form content
    with_typing_indicator do
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: rendered[:content],
          content_type: rendered[:content_type],
          content_attributes: rendered[:content_attributes]
        )
      ).perform
    end

    # Form will be automatically sent via SendReplyJob callback
    log_info '[Bot] Guitar Info Form sent successfully'
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send guitar info form: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
    # Fallback to guitar list on error
    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def send_large_content_form
    # Send large content form (template 343)
    # Force reload to bust any Rails caching
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 343
    )&.reload

    unless template
      Rails.logger.error utf8_encode('[Bot] Large Content Form template (ID: 343) not found')
      send_text_message('Large content form is not available.')
      return
    end

    log_info "[Bot] 📋 Sending Large Content Form (ID: 343, Name: #{utf8_encode(template.name)})"

    # Use BotRendererService to properly render the template
    renderer = Templates::BotRendererService.new(
      template_id: 343,
      parameters: {},
      channel_type: 'apple_messages_for_business'
    )

    rendered = renderer.render_for_bot

    # CRITICAL: Ensure content_type is 'apple_form' so IncomingMessageService can detect form responses
    rendered[:content_type] = 'apple_form' if rendered[:content_type] != 'apple_form'

    # Add request_identifier for proper routing to handle_large_form_response
    rendered[:content_attributes]['request_identifier'] = 'form_large_content' if rendered[:content_attributes]['request_identifier'].blank?

    log_info "[Bot] 📋 Form content_type: #{rendered[:content_type]}"
    log_info "[Bot] 📋 Form request_identifier: #{utf8_encode(rendered[:content_attributes]['request_identifier'])}"

    # Create outgoing message with form content
    with_typing_indicator do
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: rendered[:content],
          content_type: rendered[:content_type],
          content_attributes: rendered[:content_attributes]
        )
      ).perform
    end

    # Form will be automatically sent via SendReplyJob callback
    log_info '[Bot] 📋 Large Content Form sent successfully'
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] ❌ Failed to send large content form: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def handle_large_form_response(content_attributes)
    log_info '[Bot] 📋 ========================================='
    log_info '[Bot] 📋 LARGE FORM RESPONSE RECEIVED'
    log_info '[Bot] 📋 ========================================='

    # Log raw content_attributes
    sanitized_attrs = LogSanitizerService.sanitize_for_log(content_attributes)
    log_info "[Bot] 📋 Raw content_attributes: #{utf8_encode(sanitized_attrs).inspect}"

    # Extract form data
    form_fields = nil
    if content_attributes.is_a?(Hash) && content_attributes['idr_processed'] && content_attributes['interactive_response'].present?
      log_info '[Bot] ✅ IDR already processed by IncomingMessageService'
      log_info '[Bot] 📋 ========================================='
      log_info '[Bot] 📋 DECODED INTERACTIVE DATA:'
      log_info "[Bot] 📋 #{utf8_encode(JSON.pretty_generate(content_attributes['interactive_response']))}"
      log_info '[Bot] 📋 ========================================='

      # Parse form response from decoded interactive data
      form_fields = parse_decoded_form_response(content_attributes['interactive_response'])
    elsif content_attributes.is_a?(Hash) && content_attributes['form_response'].present?
      # Standard form response format (non-IDR) - direct form data
      log_info '[Bot] 📋 Standard format (non-IDR) - parsing directly'
      form_fields = parse_form_response_data(content_attributes)
    else
      log_warn '[Bot] ⚠️  Unexpected form response format'
      log_warn "[Bot] ⚠️  content_attributes keys: #{utf8_encode(content_attributes.keys).inspect}"
    end

    # Send form values back to user
    if form_fields.present?
      send_text_message('Thank you for completing the form! Here are the values you provided:')
      send_text_message("\n" + format_form_fields(form_fields))
    else
      send_text_message('Thank you for your form submission!')
    end

    send_text_message("Type 'startover' to restart the conversation.")

    log_info '[Bot] ⏸️  Bot paused after large form response'
    log_info '[Bot] 📋 ========================================='
  end

  def parse_decoded_form_response(decoded_payload)
    # Parse the decoded form response and return all fields
    # The decoded payload may have different structures depending on the IDR format

    # Try different possible paths where form selections might be located
    form_data = decoded_payload.dig('form_response', 'selections') ||
                decoded_payload.dig('data', 'dynamic', 'selections') ||
                decoded_payload.dig('dynamic', 'selections') ||
                decoded_payload['selections'] ||
                []

    log_info "[Bot] 📝 Form has #{form_data.length} field(s)"

    # Extract and return field data
    fields = []
    form_data.each_with_index do |section, index|
      title = section['title']
      value = section.dig('items', 0, 'value')

      log_info "[Bot] 📝 Field #{index + 1}: #{utf8_encode(title)} = #{utf8_encode(value).inspect}"
      fields << { title: title, value: value } if title.present?
    end

    fields
  end

  def parse_form_response_data(content_attributes)
    # Parse standard format form response and return all fields
    form_data = content_attributes.dig('form_response', 'selections') || []

    log_info "[Bot] 📝 Form has #{form_data.length} field(s)"

    # Extract and return field data
    fields = []
    form_data.each_with_index do |section, index|
      title = section['title']
      value = section.dig('items', 0, 'value')

      log_info "[Bot] 📝 Field #{index + 1}: #{utf8_encode(title)} = #{utf8_encode(value).inspect}"
      fields << { title: title, value: value } if title.present?
    end

    fields
  end

  def format_form_fields(fields)
    # Format the fields as a readable message
    fields.map do |field|
      "• #{field[:title]}: #{field[:value] || '(not provided)'}"
    end.join("\n")
  end

  def send_summary_list_picker
    # Get summary list picker template by ID
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 355
    )

    unless template
      Rails.logger.error utf8_encode('[Bot] Summary List Picker template (ID: 355) not found')
      send_text_message('Summary temporarily unavailable.')
      return
    end

    log_info "[Bot] Sending Summary List Picker (ID: 355, Name: #{utf8_encode(template.name)})"

    # UNIFIED APPROACH: Use TemplateFacade for consistent data access
    facade = AppleMessagesForBusiness::TemplateFacade.new(template)
    data = facade.load_data('list_picker')

    log_info "[Bot] 📋 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"

    # All data is now in consistent snake_case format
    sections = data['sections'] || []
    received_image_id = data['received_image_identifier']
    reply_image_id = data['reply_image_identifier']
    received_title = data['received_title']
    received_subtitle = data['received_subtitle']
    received_style = data['received_style']
    reply_title = data['reply_title']
    reply_subtitle = data['reply_subtitle']
    reply_style = data['reply_style']
    images_array = data['images']

    log_info "[Bot] 📋 Sections present: #{sections.present?}, count: #{sections&.length || 0}"

    if sections.blank?
      Rails.logger.error utf8_encode('[Bot] Summary List Picker template has no sections')
      send_text_message('Summary temporarily unavailable.')
      return
    end

    # Build content_attrs from extracted variables
    content_attrs = {
      'sections' => sections,
      'request_identifier' => 'lp_summary_0319'
    }

    # Add received_message fields if present
    if received_title.present?
      content_attrs['received_title'] = received_title
      content_attrs['received_subtitle'] = received_subtitle
      content_attrs['received_image_identifier'] = received_image_id
      content_attrs['received_style'] = received_style
    end

    # Add reply_message fields if present
    if reply_title.present?
      content_attrs['reply_title'] = reply_title
      content_attrs['reply_subtitle'] = reply_subtitle
      content_attrs['reply_image_identifier'] = reply_image_id
      content_attrs['reply_style'] = reply_style
    end

    # Clean up images array - only keep allowed keys
    if images_array.is_a?(Array)
      content_attrs['images'] = images_array.map do |image|
        {
          'identifier' => image['identifier'],
          'data' => image['data'],
          'description' => image['description']
        }.compact
      end
    end

    # NOTE: Message will be automatically sent via after_commit callback
    # which routes to SendListPickerService based on content_type
    Messages::MessageBuilder.new(
      message_sender,
      @conversation,
      bot_message_params(
        message_type: :outgoing,
        content: 'Feature Sheet',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      )
    ).perform
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send summary list picker: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_menu_list_picker
    # Get menu list picker template by ID
    log_info "[Bot] 🔍 Looking for menu template 366 in account: #{@conversation.account_id}"

    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 366
    )

    unless template
      # Debug: Check if template exists globally (different account)
      global_template = MessageTemplate.find_by(id: 366)
      if global_template
        Rails.logger.error utf8_encode("[Bot] ⚠️  Menu template 366 EXISTS but in account #{global_template.account_id}, not #{@conversation.account_id}")
        Rails.logger.error utf8_encode("[Bot] 💡 Inbox: #{@conversation.inbox_id}, Conversation: #{@conversation.id}")
      else
        Rails.logger.error utf8_encode('[Bot] ❌ Menu List Picker template (ID: 366) not found in ANY account')
      end
      send_text_message('Menu temporarily unavailable.')
      return
    end

    log_info "📋 [Bot] Sending Menu List Picker (ID: 366, Name: #{utf8_encode(template.name)})"

    # Use TemplateFacade with image loading (latest implementation)
    facade = AppleMessagesForBusiness::TemplateFacade.new(template)

    # Load data WITH images using the new method (replaces manual fetch_and_encode_images)
    data = facade.load_data_with_images('list_picker')

    log_info "[Bot] 📋 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"
    log_info "[Bot] 📋 Loaded template with #{data['images']&.length || 0} images"

    # All data is in snake_case format with images included
    sections = data['sections'] || []
    images = data['images'] || []
    received_image_id = data['received_image_identifier']
    reply_image_id = data['reply_image_identifier']
    received_title = data['received_title']
    received_subtitle = data['received_subtitle']
    received_style = data['received_style']
    reply_title = data['reply_title']
    reply_subtitle = data['reply_subtitle']
    reply_style = data['reply_style']

    log_info "[Bot] 📋 Sections present: #{sections.present?}, count: #{sections&.length || 0}"

    if sections.blank?
      Rails.logger.error utf8_encode('[Bot] ❌ Menu List Picker template has no sections')
      send_text_message('Menu temporarily unavailable.')
      return
    end

    # Build content attributes with all components (images already loaded by facade)
    content_attrs = {
      'sections' => sections,
      'images' => images,
      'request_identifier' => 'lp_menu_0319'
    }

    # Add received_message fields
    if received_title.present?
      content_attrs['received_title'] = received_title
      content_attrs['received_subtitle'] = received_subtitle
      content_attrs['received_image_identifier'] = received_image_id
      content_attrs['received_style'] = received_style
    end

    # Add reply_message fields
    if reply_title.present?
      content_attrs['reply_title'] = reply_title
      content_attrs['reply_subtitle'] = reply_subtitle
      content_attrs['reply_image_identifier'] = reply_image_id
      content_attrs['reply_style'] = reply_style
    end

    # Create outgoing message with list picker content including images
    # NOTE: Message will be automatically sent via after_commit callback
    # which routes to SendListPickerService based on content_type
    Messages::MessageBuilder.new(
      message_sender,
      @conversation,
      bot_message_params(
        message_type: :outgoing,
        content: 'Select an option',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      )
    ).perform

    log_info '[Bot] Menu List Picker sent successfully'
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send menu list picker: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_ar_file
    # Use template 344 for AR content
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 344
    )

    unless template
      Rails.logger.error utf8_encode('[Bot] AR template (ID: 344) not found - sending placeholder')
      send_text_message('[AR File: Template 344 not found]')
      return
    end

    log_info "[Bot] 🎸 Sending AR content (ID: 344, Name: #{utf8_encode(template.name)})"

    # Check if template has AR file attached
    unless template.attachments.attached?
      Rails.logger.error utf8_encode('[Bot] AR template has no attachments - sending placeholder')
      send_text_message('[AR File: No AR file attached to template]')
      return
    end

    with_typing_indicator do
      # Build message params
      sender = message_sender
      params = bot_message_params(
        message_type: :outgoing,
        content: 'Check out this guitar in AR!',
        content_type: 'text',
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
        conversation_id: @conversation.id
      )
      params[:sender] = sender

      # Create message WITHOUT saving (build, not create)
      message = @conversation.messages.build(params)

      # Copy AR file attachment(s) from template BEFORE saving message
      template.attachments.each do |template_attachment|
        # Download the file from template's ActiveStorage
        file_data = template_attachment.download

        # Create new attachment for the message
        message_attachment = message.attachments.build(
          account_id: message.account_id,
          file_type: :file
        )

        # Attach the file
        message_attachment.file.attach(
          io: StringIO.new(file_data),
          filename: template_attachment.filename.to_s,
          content_type: template_attachment.content_type
        )

        log_info "[Bot] 🎸 Attached AR file: #{utf8_encode(template_attachment.filename.to_s)} (#{template_attachment.content_type})"
      end

      # NOW save the message - this triggers after_commit with attachments already present
      # The after_commit will see attachments and wait 2 seconds before sending
      message.save!

      log_info "[Bot] 🎸 AR message saved with #{message.attachments.count} attachment(s)"
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send AR file: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
    send_text_message('[AR File: Error sending AR content]')
  end

  def send_ar_view_question
    # Send question with quick reply (message parameter handles text + buttons together)
    send_quick_reply(
      title: 'Did you see the AR view?',
      request_id: 'qr_view_ar',
      message: 'Did you click on the image and see the 3D augmented reality view of the guitar?',
      items: [
        { title: 'Yes', identifier: '111' },
        { title: 'No', identifier: '222' }
      ]
    )
  end

  def send_ar_place_question
    # Send question with quick reply (message parameter handles text + buttons together)
    send_quick_reply(
      title: 'Did you place the AR object?',
      request_id: 'qr_place_ar',
      message: 'Did you select AR from the top of the image and set it down in front of you?',
      items: [
        { title: 'Yes', identifier: '111' },
        { title: 'No', identifier: '222' }
      ]
    )
  end

  def send_apple_pay_request(guitar_name)
    with_typing_indicator do
      # Get guitar image identifier based on selected guitar
      # Uses guitar_lespaul as fallback for demo mode and unmatched guitars
      image_identifier = get_guitar_image_identifier(guitar_name)

      log_info "[Bot] 💳 Apple Pay request for '#{utf8_encode(guitar_name)}' with image: #{image_identifier}"

      payment_data = {
        'request_identifier' => 'applepay_1018',
        'merchant_name' => 'Acoustic House',
        'currency_code' => 'USD',
        'country_code' => 'US',
        'line_items' => [
          {
            'label' => guitar_name,
            'amount' => '0.01',
            'type' => 'final'
          }
        ],
        'total' => {
          'label' => 'Acoustic House',
          'amount' => '0.01',
          'type' => 'final'
        },
        'received_title' => "Buy your new #{guitar_name}",
        'received_subtitle' => 'test payment',
        'received_style' => 'large',
        'received_image_identifier' => image_identifier,
        'reply_style' => 'large',
        'reply_image_identifier' => image_identifier
      }

      # Call SendApplePayService directly (synchronously) so we can handle errors
      service = AppleMessagesForBusiness::SendApplePayService.new(
        channel: @conversation.inbox.channel,
        destination_id: @conversation.contact_inbox.source_id,
        payment_data: payment_data
      )

      log_info '[Bot] 💳 Calling SendApplePayService.perform...'
      response = service.perform
      log_info "[Bot] 💳 SendApplePayService returned: #{response.inspect}"
      log_info "[Bot] 💳 Response is Hash: #{response.is_a?(Hash)}"
      log_info "[Bot] 💳 Response[:success]: #{response[:success].inspect}"
      log_info "[Bot] 💳 Response[:success] == true: #{response[:success] == true}"

      # If service succeeded, create message record without triggering SendReplyJob
      if response[:success]
        # Clean up payment_data for storage - remove keys that aren't needed in database
        stored_payment_data = payment_data.except('request_identifier', 'reply_image_identifier')

        # Create message directly to avoid double-send via SendReplyJob
        message_params = bot_message_params(
          message_type: :outgoing,
          content: "Buy your new #{guitar_name}",
          content_type: 'apple_pay',
          content_attributes: stored_payment_data,
          source_id: response[:message_id],
          sender: message_sender,
          account_id: @conversation.account_id,
          inbox_id: @conversation.inbox_id,
          conversation_id: @conversation.id
        )

        # Use create without ! to avoid exception if message already exists
        message = @conversation.messages.create(message_params)

        if message.persisted?
          log_info '[Bot] ✅ Apple Pay message created successfully'
        else
          log_warn "[Bot] ⚠️ Apple Pay message creation failed: #{message.errors.full_messages.join(', ')}"
          log_warn '[Bot] ⚠️ Payment was delivered to device, continuing anyway...'
        end

        log_info '[Bot] ✅ Apple Pay sent successfully - returning { success: true }'
        return_value = { success: true }
        log_info "[Bot] 💳 About to return: #{return_value.inspect}"
        return_value
      else
        log_info "[Bot] ❌ Apple Pay failed: #{utf8_encode(response[:error])}"
        log_info "[Bot] 💳 About to return response: #{response.inspect}"
        response
      end
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] 💳 Exception in send_apple_pay_request: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
    error_return = { success: false, error: e.message }
    log_info "[Bot] 💳 Returning error: #{error_return.inspect}"
    error_return
  end

  def send_document(filename)
    # Load document file from public/demo_files/apple_messages/
    file_path = Rails.public_path.join('demo_files', 'apple_messages', filename)

    unless File.exist?(file_path)
      Rails.logger.error utf8_encode("[Bot] Document not found: #{file_path}")
      return
    end

    log_info "[Bot] Sending document: #{utf8_encode(filename)}"

    with_typing_indicator do
      # Build message params
      sender = message_sender
      params = bot_message_params(
        message_type: :outgoing,
        content: '',  # Empty content - attachment will display filename
        content_type: 'text',
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
        conversation_id: @conversation.id
      )
      params[:sender] = sender

      # Create message WITHOUT saving (build, not create)
      message = @conversation.messages.build(params)

      # Read file data and attach using StringIO (avoids file handle closing issues)
      file_data = File.binread(file_path)

      message_attachment = message.attachments.build(
        account_id: message.account_id,
        file_type: :file
      )

      # Attach the file using StringIO
      message_attachment.file.attach(
        io: StringIO.new(file_data),
        filename: filename,
        content_type: mime_type_for_filename(filename)
      )

      log_info "[Bot] Attached file: #{utf8_encode(filename)} (#{file_data.size} bytes)"

      # NOW save the message - this triggers after_commit with attachments already present
      message.save!

      log_info "[Bot] Document message saved with #{message.attachments.count} attachment(s)"
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send document: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def mime_type_for_filename(filename)
    case File.extname(filename).downcase
    when '.pdf'
      'application/pdf'
    when '.numbers'
      'application/vnd.apple.numbers'
    when '.pages'
      'application/vnd.apple.pages'
    when '.key'
      'application/vnd.apple.keynote'
    else
      'application/octet-stream'
    end
  end

  def send_rich_link(url:, image_asset:, title:)
    # Send a rich link message with URL, image, and title
    # Image asset is optional (can be nil or a filename)
    log_info "[Bot] Sending rich link: #{utf8_encode(url)} (#{utf8_encode(title)})"

    with_typing_indicator do
      # Create message with rich link content
      # NOTE: Message will be automatically sent via after_commit callback
      # which routes to SendRichLinkService based on content_type
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: url,
          content_type: 'apple_rich_link',
          content_attributes: {
            'url' => url,
            'title' => title,
            'image_url' => image_url_for_asset(image_asset)
          }.compact
        )
      ).perform
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send rich link: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def image_url_for_asset(image_asset)
    # Map image asset filename to public URL
    # For now, return nil if no asset (Apple will fetch og:image from URL)
    return nil if image_asset.blank?

    # If it's already a full URL, return as-is
    return image_asset if image_asset.start_with?('http://', 'https://')

    # For demo assets in public directory, construct URL if we have a base URL
    # Try to get the frontend URL from installation config
    base_url = ENV.fetch('FRONTEND_URL', nil) || @conversation.inbox&.channel&.webhook_url&.match(%r{^https?://[^/]+})&.to_s

    if base_url.present?
      # Construct full URL for the asset
      "#{base_url}/demo_files/apple_messages/#{image_asset}"
    else
      # No base URL available - return nil to let Apple fetch from target URL's og:image
      nil
    end
  end

  def get_conversation_attribute(key)
    attrs = @conversation.custom_attributes || {}
    attrs[key]
  end

  def increment_retry_count
    attrs = @conversation.custom_attributes || {}
    count = (attrs['retry_count'] || 0) + 1

    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes['retry_count'] = count
    @conversation.save!

    count
  end

  def reset_retry_count
    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes['retry_count'] = 0
    @conversation.save!
  end

  def update_conversation_attribute(key, value)
    @conversation.custom_attributes ||= {}
    @conversation.custom_attributes[key] = value
    @conversation.save!
  end

  # Helper method to build message params with bot sender
  def bot_message_params(base_params)
    agent_bot = bot_user

    # Only add sender_type and sender_id if we have an AgentBot
    if agent_bot.present?
      base_params.merge(
        sender_type: 'AgentBot',
        sender_id: agent_bot.id
      )
    else
      # No bot assigned - messages will be sent as the user (agent)
      base_params
    end
  end

  # Helper method to get sender for MessageBuilder
  def message_sender
    # Return AgentBot if available, otherwise fall back to first user
    bot_user.presence || @conversation.account.users.first
  end

  def bot_user
    # Return the AgentBot associated with this inbox, or nil
    @conversation.inbox.agent_bot
  end

  # Typing indicator methods
  def apple_messages_channel?
    @conversation.inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
  end

  def send_typing_indicator(action)
    return unless TYPING_INDICATORS_ENABLED
    return unless apple_messages_channel?

    # Get the Apple Messages source ID from contact's additional attributes
    apple_source_urn = @conversation.contact&.additional_attributes&.dig('apple_messages_source_id')
    return unless apple_source_urn # Need destination ID

    # Extract the UUID from the URN format (urn:biz:UUID)
    destination_id = apple_source_urn.sub(/^urn:biz:/, '')

    service = AppleMessagesForBusiness::OutgoingTypingIndicatorService.new(
      channel: @conversation.inbox.channel,
      destination_id: destination_id,
      action: action
    )

    result = service.perform
    log_info "[AcousticHouseBot] Typing indicator #{action}: #{result[:success] ? 'success' : utf8_encode(result[:error])}"
  rescue StandardError => e
    Rails.logger.error utf8_encode("[AcousticHouseBot] Failed to send typing indicator: #{e.message}")
    # Don't fail the message sending if typing indicator fails
  end

  # Extract address information from form response
  # Looks for common address field patterns (street, city, state, zip, address, etc.)
  def extract_address_from_form(form_data)
    return nil if form_data.blank?

    address_fields = {}

    # Common address field patterns
    field_patterns = {
      street: ['street', 'address', 'addr', 'line 1', 'address line'],
      city: %w[city town],
      state: %w[state province region],
      zip: ['zip', 'postal', 'postcode', 'zip code', 'postal code'],
      country: ['country']
    }

    # Search through form sections for address fields
    form_data.each do |section|
      title = section['title']&.downcase || ''
      value = section.dig('items', 0, 'value')

      next unless value.present?

      # Match against patterns
      field_patterns.each do |field_type, patterns|
        if patterns.any? { |pattern| title.include?(pattern) }
          address_fields[field_type] = value
          break
        end
      end
    end

    # Return nil if no address fields found
    return nil if address_fields.empty?

    # Return formatted address hash
    address_fields
  end

  # Send delivery confirmation message with address
  def send_delivery_confirmation(address_data, customer_name = nil)
    return unless address_data.present?

    # Build formatted address string
    address_parts = []
    address_parts << address_data[:street] if address_data[:street].present?
    address_parts << address_data[:city] if address_data[:city].present?
    address_parts << address_data[:state] if address_data[:state].present?
    address_parts << address_data[:zip] if address_data[:zip].present?
    address_parts << address_data[:country] if address_data[:country].present?

    formatted_address = address_parts.join(', ')

    # Build confirmation message
    message = if customer_name.present?
                "Perfect #{customer_name}! Your order will be delivered to: #{formatted_address}"
              else
                "Perfect! Your order will be delivered to: #{formatted_address}"
              end

    send_text_message(message)

    log_info "[Bot] 📦 Sent delivery confirmation for address: #{utf8_encode(formatted_address)}"
  end

  def with_typing_indicator
    return yield unless TYPING_INDICATORS_ENABLED

    send_typing_indicator(:start)
    sleep(TYPING_INDICATOR_DELAY)
    result = yield
    send_typing_indicator(:end)
    result
  rescue StandardError => e
    send_typing_indicator(:end) # Always end typing indicator
    raise e
  end

  # === Phase 3 Helper Methods ===

  def geocode_zipcode(zipcode)
    # MVP: Hardcoded zipcode lookup
    location = LOCATION_DATABASE[zipcode.strip]

    # Default fallback: Apple Park
    location || LOCATION_DATABASE['95014']
  end

  def send_lesson_time_picker(location)
    guitar = get_conversation_attribute('selected_guitar') || 'guitar'

    # Generate timeslots 7-8 days from now
    day1 = 7.days.from_now.to_date
    day2 = 8.days.from_now.to_date

    timeslots = [
      { 'identifier' => '0', 'start_time' => "#{day1}T15:30#{location[:timezone_offset]}", 'duration' => 3600 },
      { 'identifier' => '1', 'start_time' => "#{day1}T17:00#{location[:timezone_offset]}", 'duration' => 3600 },
      { 'identifier' => '2', 'start_time' => "#{day1}T19:30#{location[:timezone_offset]}", 'duration' => 3600 },
      { 'identifier' => '3', 'start_time' => "#{day2}T15:00#{location[:timezone_offset]}", 'duration' => 3600 },
      { 'identifier' => '4', 'start_time' => "#{day2}T17:30#{location[:timezone_offset]}", 'duration' => 3600 },
      { 'identifier' => '5', 'start_time' => "#{day2}T19:00#{location[:timezone_offset]}", 'duration' => 3600 }
    ]

    # Define image identifier for time picker (must be pre-loaded via upload_time_picker_image.rb)
    time_picker_image_id = 'time_picker_lesson'

    # NOTE: Time pickers use image identifiers only (received_image_identifier, reply_image_identifier)
    # Unlike list pickers, they do NOT use an 'images' array in content_attributes
    # The images must be pre-uploaded to AppleListPickerImage model by identifier

    with_typing_indicator do
      # Create message with time picker content
      # NOTE: Message will be automatically sent via after_commit callback
      # which routes to SendTimePickerService based on content_type
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: "Schedule a lesson with your #{guitar}",
          content_type: 'apple_time_picker',
          content_attributes: {
            'request_identifier' => 'time_0319',
            'received_title' => "Schedule a lesson with your #{guitar}",
            'received_subtitle' => location[:name],
            'received_image_identifier' => time_picker_image_id,
            'reply_title' => 'Thank you!',
            'reply_image_identifier' => time_picker_image_id,
            'event' => {
              'identifier' => SecureRandom.uuid,
              'title' => "Guitar Lesson - #{guitar}",
              'location' => {
                'latitude' => location[:latitude],
                'longitude' => location[:longitude],
                'radius' => 300.0,
                'title' => location[:name]
              },
              'timeslots' => timeslots
            }
          }
        )
      ).perform
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send time picker: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_single_store_rich_link(store, _user_coordinates)
    # Single store found - send as Apple Maps rich link and proceed directly to time picker
    log_info "[Bot] 📍 Single store found: #{utf8_encode(store[:name])}"

    # Build Apple Maps URL for the store
    # Prefer using place ID if available, otherwise use coordinates + name
    maps_url = if store[:id].present?
                 # Use Apple Maps place ID for more accurate link
                 "https://maps.apple.com/place?place-id=#{store[:id]}"
               else
                 # Fallback to coordinates + query
                 "https://maps.apple.com/?ll=#{store[:latitude]},#{store[:longitude]}&q=#{CGI.escape(store[:name])}"
               end

    log_info "[Bot] 📍 Generated Apple Maps URL: #{utf8_encode(maps_url)}"

    # Calculate timezone
    timezone_offset = calculate_timezone_offset(store[:longitude])

    # Create location hash for time picker
    location = {
      name: store[:name],
      latitude: store[:latitude],
      longitude: store[:longitude],
      timezone_offset: timezone_offset
    }

    # Store selection
    update_conversation_attribute('selected_store_name', store[:name])

    # Send confirmation message first
    reset_retry_count
    send_text_message('Please find the store information of your appointment')

    # Then send rich link message (Open Graph scraping will handle title/image automatically)
    send_rich_link(
      url: maps_url,
      title: store[:name],
      image_asset: nil
    )

    # Wait for rich link to be fully delivered before sending time picker
    sleep(2.0)

    # Finally send time picker
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send single store rich link: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_store_quick_reply(stores, user_coordinates)
    # 2-5 stores - send as quick reply buttons
    log_info "[Bot] 🏪 Sending #{stores.length} stores as quick reply"

    # Store minimal stores data
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
    update_conversation_attribute('store_search_lat', user_coordinates[:latitude])
    update_conversation_attribute('store_search_lon', user_coordinates[:longitude])

    # Build quick reply items
    items = stores.map.with_index do |store, index|
      {
        title: store[:name],
        value: index.to_s
      }
    end

    # Send quick reply
    send_quick_reply(
      title: "Select your nearest Apple Store (#{stores.length} found)",
      request_id: 'qr_store_selection',
      items: items
    )
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send store quick reply: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def send_store_selection_list_picker(stores, user_coordinates)
    return if stores.blank?

    # Image identifier for Apple Store logo
    apple_store_image_id = 'apple_store_logo'

    # Build list picker sections with store items (including image identifier)
    items = stores.map.with_index do |store, index|
      {
        'identifier' => index.to_s,
        'title' => store[:name],
        'subtitle' => "#{store[:distance_km]} km away • #{store[:formatted_address]}",
        'style' => 'large',
        'image_identifier' => apple_store_image_id
      }
    end

    sections = [
      {
        'title' => 'Nearby Apple Stores',
        'multiple_selection' => false,
        'items' => items
      }
    ]

    # Store search coordinates in conversation attributes for later use
    update_conversation_attribute('store_search_lat', user_coordinates[:latitude])
    update_conversation_attribute('store_search_lon', user_coordinates[:longitude])

    # Store minimal stores data (without long addresses) to avoid exceeding attribute length limit
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

    # Fetch and encode the Apple Store logo image
    images = fetch_and_encode_images([apple_store_image_id])

    log_info "[Bot] 🏪 Encoded #{images.length} images for store selection list picker"

    with_typing_indicator do
      # Create message with list picker content
      # NOTE: Message will be automatically sent via after_commit callback
      # which routes to SendListPickerService based on content_type
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: 'Select an Apple Store',
          content_type: 'apple_list_picker',
          content_attributes: {
            'request_identifier' => 'lp_store_selection',
            'sections' => sections,
            'images' => images,
            'received_title' => 'Select a Store',
            'received_subtitle' => "Found #{stores.length} stores nearby",
            'received_image_identifier' => apple_store_image_id,
            'reply_title' => 'Great choice!',
            'reply_subtitle' => 'Let\'s schedule your lesson',
            'reply_image_identifier' => apple_store_image_id
          }
        )
      ).perform
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send store selection list picker: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
  end

  def handle_store_selection(interactive_data)
    log_info '[Bot] 🏪 handle_store_selection called'
    log_info "[Bot] 🏪 Called from: #{caller[0..2].join("\n")}"
    log_info "[Bot] 🏪 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"

    # Idempotency guard: prevent processing the same store selection twice
    selection_data = interactive_data['ldtext'] || interactive_data.dig('data', 'listPicker', 'sections')&.to_json || 'unknown'
    selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
    selection_key = "store_selection:#{selection_hash}"

    if Redis::Alfred.get(selection_key).present?
      log_info "[Bot] 🏪 Store selection already processed (hash: #{selection_hash}), skipping"
      return
    end

    # Mark as processed (expires after 2 minutes)
    Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
    log_info "[Bot] 🏪 Store selection marked as processed (hash: #{selection_hash})"

    # Extract selection from interactive data
    selected_index = if interactive_data['ldtext'].present?
                       # Resolved NSKeyedArchiver/IDR format - extract index from ldtext
                       # The ldtext might contain store name, we need to find the index
                       store_title = interactive_data['ldtext']
                       log_info "[Bot] 🏪 IDR format store selection (ldtext): #{utf8_encode(store_title)}"

                       # Get available stores from conversation attributes
                       stores_json = get_conversation_attribute('available_stores')
                       if stores_json
                         stores = JSON.parse(stores_json)
                         found_store = stores.find { |s| s['name'] == store_title }
                         stores.index(found_store) if found_store
                       end
                     elsif interactive_data['$archiver'] == 'NSKeyedArchiver'
                       # Raw NSKeyedArchiver format - extract from $objects array
                       objects = interactive_data['$objects'] || []
                       # Find the identifier (should be a number string)
                       objects.find { |obj| obj.is_a?(String) && obj.match?(/^\d+$/) }
                     elsif interactive_data.dig('data', 'listPicker', 'sections').present?
                       # List picker format with sections - extract from "You Selected" section
                       sections = interactive_data.dig('data', 'listPicker', 'sections') || []
                       selected_section = sections.find { |s| s['title'] == 'You Selected' }
                       if selected_section
                         selected_item = selected_section.dig('items', 0)
                         selected_item&.fetch('identifier', nil)
                       end
                     else
                       # Standard format
                       interactive_data.dig('data', 'reply', 'identifier')
                     end

    log_info "[Bot] 🏪 Selected store index: #{selected_index}"

    # Get available stores from conversation attributes
    stores_json = get_conversation_attribute('available_stores')
    unless stores_json
      Rails.logger.error utf8_encode('[Bot] 🏪 No available stores found in conversation attributes')
      send_text_message('Sorry, store selection expired. Please provide your location again.')
      update_bot_state('AHG1')
      return
    end

    stores = JSON.parse(stores_json)
    selected_store = stores[selected_index.to_i]

    unless selected_store
      Rails.logger.error utf8_encode("[Bot] 🏪 Invalid store index: #{selected_index}")
      send_text_message('Sorry, invalid store selection. Please try again.')
      update_bot_state('AHG1')
      return
    end

    # Store selected store details
    update_conversation_attribute('selected_store_name', selected_store['name'])
    # NOTE: We don't store formatted_address anymore (removed for size limits)

    # Build Apple Maps URL for the selected store
    maps_url = if selected_store['id'].present?
                 "https://maps.apple.com/place?place-id=#{selected_store['id']}"
               else
                 "https://maps.apple.com/?ll=#{selected_store['latitude']},#{selected_store['longitude']}&q=#{CGI.escape(selected_store['name'])}"
               end

    log_info "[Bot] 🏪 Sending rich link for selected store: #{utf8_encode(maps_url)}"

    # Send confirmation and rich link
    send_text_message('Please find the store information of your appointment')

    # Send rich link to the store (Open Graph scraping will handle title/image automatically)
    send_rich_link(
      url: maps_url,
      title: selected_store['name'],
      image_asset: nil
    )

    # Wait for rich link to be fully delivered before sending time picker
    sleep(2.0)

    # Calculate timezone offset based on longitude
    timezone_offset = calculate_timezone_offset(selected_store['longitude'])

    # Create location hash for time picker
    location = {
      name: selected_store['name'],
      latitude: selected_store['latitude'],
      longitude: selected_store['longitude'],
      timezone_offset: timezone_offset
    }

    reset_retry_count

    # Send time picker
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] 🏪 Error in handle_store_selection: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))

    # Fallback
    send_text_message('Sorry, there was an error processing your selection.')
    update_bot_state('AHG1')
  end

  def handle_store_selection_qr(interactive_data)
    # Handle quick reply store selection (2-5 stores case)
    log_info '[Bot] 🏪 handle_store_selection_qr called'
    log_info "[Bot] 🏪 Called from: #{caller[0..2].join("\n")}"
    log_info "[Bot] 🏪 interactive_data keys: #{utf8_encode(interactive_data.keys).inspect}"

    # Idempotency guard: prevent processing the same store selection twice
    selection_data = interactive_data.dig('data', 'quick-reply')&.to_json || interactive_data['$objects']&.to_json || 'unknown'
    selection_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{selection_data}")
    selection_key = "store_selection_qr:#{selection_hash}"

    if Redis::Alfred.get(selection_key).present?
      log_info "[Bot] 🏪 Store selection (QR) already processed (hash: #{selection_hash}), skipping"
      return
    end

    # Mark as processed (expires after 2 minutes)
    Redis::Alfred.setex(selection_key, '1', 2.minutes.to_i)
    log_info "[Bot] 🏪 Store selection (QR) marked as processed (hash: #{selection_hash})"

    # Extract selected index from quick reply
    selected_index = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                       # NSKeyedArchiver format - extract index from $objects array
                       objects = interactive_data['$objects'] || []
                       # Find the index (should be a number string like "0", "1", etc.)
                       objects.find { |obj| obj.is_a?(String) && obj.match?(/^\d+$/) }
                     else
                       # Standard quick reply format
                       quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                       selected_index_int = quick_reply_data['selectedIndex']
                       items = quick_reply_data['items'] || []

                       # Get the value from the selected item
                       items[selected_index_int]&.fetch('title', nil) if selected_index_int
                     end

    log_info "[Bot] 🏪 Selected store index from quick reply: #{selected_index}"

    # Get available stores from conversation attributes
    stores_json = get_conversation_attribute('available_stores')
    unless stores_json
      Rails.logger.error utf8_encode('[Bot] 🏪 No available stores found in conversation attributes')
      send_text_message('Sorry, store selection expired. Please provide your location again.')
      update_bot_state('AHG1')
      return
    end

    stores = JSON.parse(stores_json)
    selected_store = stores[selected_index.to_i]

    unless selected_store
      Rails.logger.error utf8_encode("[Bot] 🏪 Invalid store index: #{selected_index}")
      send_text_message('Sorry, invalid store selection. Please try again.')
      update_bot_state('AHG1')
      return
    end

    # Store selected store details
    update_conversation_attribute('selected_store_name', selected_store['name'])

    # Build Apple Maps URL for the selected store
    maps_url = if selected_store['id'].present?
                 "https://maps.apple.com/place?place-id=#{selected_store['id']}"
               else
                 "https://maps.apple.com/?ll=#{selected_store['latitude']},#{selected_store['longitude']}&q=#{CGI.escape(selected_store['name'])}"
               end

    log_info "[Bot] 🏪 Sending rich link for selected store: #{utf8_encode(maps_url)}"

    # Send confirmation and rich link
    send_text_message('Please find the store information of your appointment')

    # Send rich link to the store (Open Graph scraping will handle title/image automatically)
    send_rich_link(
      url: maps_url,
      title: selected_store['name'],
      image_asset: nil
    )

    # Wait for rich link to be fully delivered before sending time picker
    sleep(2.0)

    # Calculate timezone offset
    timezone_offset = calculate_timezone_offset(selected_store['longitude'])

    # Create location hash for time picker
    location = {
      name: selected_store['name'],
      latitude: selected_store['latitude'],
      longitude: selected_store['longitude'],
      timezone_offset: timezone_offset
    }

    reset_retry_count

    # Send time picker
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] 🏪 Error in handle_store_selection_qr: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))

    # Fallback
    send_text_message('Sorry, there was an error processing your selection.')
    update_bot_state('AHG1')
  end

  def send_apple_messages_rich_link
    with_typing_indicator do
      # Create message with rich link
      # NOTE: Message will be automatically sent via after_commit callback
      # which routes to SendRichLinkService based on content_type
      Messages::MessageBuilder.new(
        message_sender,
        @conversation,
        bot_message_params(
          message_type: :outgoing,
          content: 'https://register.apple.com/resources/messages/messaging-documentation/',
          content_type: 'apple_rich_link',
          content_attributes: {
            'url' => 'https://register.apple.com/resources/messages/messaging-documentation/',
            'title' => 'Apple Messages for Business',
            'image_url' => image_url_for_asset('heroImage.png')
          }.compact
        )
      ).perform
    end
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] Failed to send rich link: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
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

  # Calculate timezone offset based on longitude
  # @param longitude [Float] Longitude coordinate
  # @return [String] Timezone offset (e.g., '-0800', '+0100')
  def calculate_timezone_offset(longitude)
    # Global timezone approximation based on longitude
    # Returns ISO 8601 timezone offset format
    if longitude < -120
      '-0800' # Pacific (US West Coast, parts of Canada/Mexico)
    elsif longitude < -105
      '-0700' # Mountain (US Mountain, parts of Mexico)
    elsif longitude < -90
      '-0600' # Central (US Central, parts of Mexico)
    elsif longitude < -60
      '-0500' # Eastern (US East Coast, parts of Canada/South America)
    elsif longitude < -30
      '-0300' # South America (Brazil, Argentina)
    elsif longitude < 15
      '+0000' # UK, Western Europe, West Africa
    elsif longitude < 30
      '+0100' # Central Europe (France, Germany, Italy)
    elsif longitude < 45
      '+0200' # Eastern Europe (Finland, Greece, South Africa)
    elsif longitude < 75
      '+0300' # Middle East (Turkey, Israel, UAE)
    elsif longitude < 105
      '+0530' # India
    elsif longitude < 120
      '+0800' # China, Singapore
    elsif longitude < 150
      '+0900' # Japan, Korea
    else
      '+1000' # Australia (East)
    end
  end

  # Check if template images are available using three-tier fallback
  # Returns hash with missing and available identifiers
  def check_template_images_available(template, inbox_id = nil)
    inbox_id ||= @conversation.inbox_id
    identifiers = template.extract_image_identifiers_from_blocks

    return { available: [], missing: [], all_available: true } if identifiers.empty?

    # Use ImageFetchService to check all three tiers (inbox → shared → embedded)
    service = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: template.account_id,
      inbox_id: inbox_id,
      embedded_images: []
    )

    # Fetch images (will return only those found in any tier)
    found_images = service.fetch_and_encode(identifiers)
    available = found_images.map { |img| img[:identifier] }
    missing = identifiers - available

    if missing.any?
      log_warn "[Bot] Template #{template.id} missing images: #{missing.inspect}"
      log_warn "[Bot] Available images: #{available.inspect}"
    end

    {
      available: available,
      missing: missing,
      all_available: missing.empty?
    }
  end

  # Map guitar names to their corresponding image identifiers
  # Returns the image identifier for the guitar, or fallback image
  # @param guitar_name [String] The name of the selected guitar
  # @return [String] The image identifier to use
  # rubocop:disable Metrics/MethodLength
  def get_guitar_image_identifier(guitar_name)
    return nil if guitar_name.blank?

    # Default fallback image (Les Paul) - used when no match found or in demo mode
    fallback_identifier = 'guitar_lespaul'

    # Guitar name to image identifier mapping
    # Based on the guitar list picker template (ID 371) items
    guitar_image_map = {
      # Exact matches from guitar list picker
      'Fender American Elite Stratocaster' => 'guitar_stratocaster',
      'Gibson ES-335' => 'guitar_gibson_es335',
      'Martin DC28E Dreadnought' => 'guitar_martin_dreadnought',
      'Gibson Les Paul Standard' => 'guitar_lespaul',
      'PRS Custom 24' => 'guitar_prs_custom24',
      'Taylor 814ce' => 'guitar_taylor',

      # Partial match patterns (for when guitar name is abbreviated)
      'Stratocaster' => 'guitar_stratocaster',
      'Les Paul' => 'guitar_lespaul',
      'Martin' => 'guitar_martin_dreadnought',
      'Dreadnought' => 'guitar_martin_dreadnought',
      'Gibson' => 'guitar_lespaul',
      'Fender' => 'guitar_stratocaster',
      'PRS' => 'guitar_prs_custom24',
      'Taylor' => 'guitar_taylor',

      # Demo mode guitars
      'Demo Guitar - Fender Stratocaster' => 'guitar_stratocaster'
    }

    # Try exact match first
    return guitar_image_map[guitar_name] if guitar_image_map.key?(guitar_name)

    # Try partial match (find first key that guitar_name includes)
    match = guitar_image_map.find { |key, _value| guitar_name.include?(key) }
    return match[1] if match

    # Log when using fallback
    Rails.logger.info "[Bot] 🎸 No image found for guitar '#{guitar_name}', using fallback: #{fallback_identifier}"

    # Return fallback image
    fallback_identifier
  end
  # rubocop:enable Metrics/MethodLength
end
