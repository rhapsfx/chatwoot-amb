# frozen_string_literal: true

class AppleMessagesForBusiness::AcousticHouseBotService
  include AppleMessagesForBusiness::BotLogging

  # Template dependencies for deployment automation
  # These templates must exist for the bot to function correctly
  # Used by deployment scripts to auto-detect required templates
  REQUIRED_TEMPLATES = %w[
    ah_guitar_list_picker
    ah_guitar_info_form
    ah_large_form_demo
    ah_main_menu
    ah_ar_guitar
    ah_summary
  ].freeze

  # Returns array of required template names
  def self.required_template_names
    REQUIRED_TEMPLATES
  end

  # Returns array of template IDs for a given account
  # @param account_id [Integer] Account ID to look up templates
  # @return [Array<Integer>] Template IDs
  def self.required_template_ids(account_id)
    MessageTemplate.where(
      account_id: account_id,
      name: REQUIRED_TEMPLATES
    ).pluck(:id)
  end

  # Verifies all required templates exist for an account
  # @param account_id [Integer] Account ID to verify
  # @return [Hash] Verification result with :all_present, :found, :missing keys
  def self.verify_templates_exist(account_id)
    found = MessageTemplate.where(
      account_id: account_id,
      name: REQUIRED_TEMPLATES
    )

    missing = REQUIRED_TEMPLATES - found.pluck(:name)

    {
      all_present: missing.empty?,
      found: found.pluck(:id, :name),
      missing: missing
    }
  end

  # Typing indicator configuration
  # Set to false during development for faster testing
  # Set to true in production for better user experience
  TYPING_INDICATORS_ENABLED = true
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
    'apple pay' => :handle_apple_pay_demo,
    'payment' => :handle_apple_pay_demo,
    'pay' => :handle_apple_pay_demo,
    'form' => :handle_form_demo,
    'help me decide' => :handle_form_demo,
    'large form' => :handle_large_form_demo,
    'big form' => :handle_large_form_demo,
    'ar' => :handle_ar_demo,
    'augmented reality' => :handle_ar_demo,
    'imessage' => :handle_imessage_app,
    'imessage app' => :handle_imessage_app,
    'imessage extension' => :handle_imessage_app,
    'authentication' => :handle_authentication_menu,
    'auth' => :handle_authentication_menu,
    'oauth' => :handle_authentication_menu,
    'shazam' => :handle_imessage_app,
    'appclip' => :handle_app_clip_demo,
    'app clip' => :handle_app_clip_demo,
    'wallet' => :handle_wallet_demo,
    'walletpass' => :handle_wallet_demo,
    'wallet pass' => :handle_wallet_demo,
    'apple wallet' => :handle_wallet_demo
  }.freeze

  # Keywords that control flow (reset, navigation, etc.)
  FLOW_CONTROL_KEYWORDS = {
    'menu' => :handle_menu,
    'start' => :handle_start_over,
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
    'lesson' => :handle_schedule_lesson,
    'appointment' => :handle_schedule_lesson,
    'time' => :handle_schedule_lesson
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
    'lp_summary_0319' => :handle_summary_selection,
    'form_large_content' => :handle_large_form_response,
    'act_imessage_app' => :handle_imessage_app,
    'qr_oauth_provider' => :handle_oauth_provider_selection
  }.freeze

  # Allowlists of methods callable via dispatch — prevents arbitrary method invocation through send()
  ALLOWED_KEYWORD_HANDLERS = (DEMO_KEYWORDS.values + FLOW_CONTROL_KEYWORDS.values).uniq.freeze
  ALLOWED_INTERACTIVE_HANDLERS = INTERACTIVE_HANDLERS.values.freeze

  def initialize(conversation, message)
    @conversation = conversation
    @message = message
    @contact = conversation.contact
    @state_manager = AppleMessagesForBusiness::BotStateManager.new(conversation)
    @sender = AppleMessagesForBusiness::BotMessageSender.new(conversation)
    @bot_state = @state_manager.current_state
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

    # Handle iMessage extension balloon responses (bid format) that have no requestIdentifier.
    # Apple sends { "bid": "...", "data": { "replyMessage": {...} }, "sessionIdentifier": "..." }
    # when the user taps a Shazam/custom-app bubble directly (no routing info available).
    # List pickers that include bid (e.g. summary LP) still carry data['requestIdentifier']
    # and must fall through to the normal routing path below.
    if interactive_data['bid'].present? && (interactive_data['data'] || {})['requestIdentifier'].blank?
      log_info '[Bot] 🎵 iMessage extension response detected (bid present, no requestIdentifier)'
      send_text_message("Type 'menu' to explore more features or 'startover' to restart.")
      return
    end

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
      safe_execute(context: "interactive(#{request_id})") do
        dispatch_interactive_handler(handler_method, interactive_data)

        # After handling the interactive response, process the updated state.
        # Skip if: handler is waiting for user input, menu selection handled it,
        # or handler put us in DEMO_MODE (it already sent its own completion message).
        waiting_states = %w[AHB1_2 AHB1 AHG1 AHJ1]
        skip_process_state_for_request_ids = %w[lp_menu_0319]

        if waiting_states.include?(@bot_state)
          log_info "[Bot] 🔄 State #{@bot_state} is waiting for user input - skipping process_state"
        elsif skip_process_state_for_request_ids.include?(request_id)
          log_info "[Bot] 🔄 Request #{request_id} handled by menu selection - skipping process_state"
        elsif @bot_state == 'DEMO_MODE'
          log_info '[Bot] 🔄 Handler completed in DEMO_MODE - skipping process_state to avoid duplicate message'
        else
          log_info "[Bot] 🔄 Interactive handler complete, processing updated state: #{@bot_state}"
          process_state
        end
      end
    else
      log_warn "[Bot] ❌ No handler for requestId: #{request_id}"
      log_warn "[Bot] 📝 Available handlers: #{INTERACTIVE_HANDLERS.keys.inspect}"
    end
  end

  private

  # === Error handling ===

  # Centralized error wrapper for all bot handler calls.
  # Catches DB errors and unexpected exceptions, sends a user-facing message,
  # and optionally transitions to a fallback state before re-raising.
  def safe_execute(context:, fallback_state: nil)
    yield
  rescue ActiveRecord::RecordInvalid => e
    log_error "[Bot] 💾 DB error in #{context}: #{e.message}"
    send_text_message("We're having a brief issue, please try again.")
  rescue StandardError => e
    log_error "[Bot] ❌ Error in #{context}: #{e.message}"
    log_error e.backtrace.first(5).join("\n")
    Sentry.capture_exception(e) if defined?(Sentry)
    update_bot_state(fallback_state) if fallback_state
    send_text_message("Something went wrong. Type 'menu' to continue.")
  end

  # === Delegation to BotStateManager ===

  def get_bot_state
    @state_manager.current_state
  end

  def update_bot_state(new_state)
    @bot_state = @state_manager.update(new_state)
  end

  def conversation_timed_out?
    @state_manager.timed_out?
  end

  def reset_to_welcome
    log_info '[Bot] 🔄 reset_to_welcome - Clearing all flow attributes'
    @bot_state = @state_manager.full_reset
    log_info '[Bot] ✅ Flow attributes cleared, ready for fresh start'
  end

  def get_conversation_attribute(key)
    @state_manager.get_attribute(key)
  end

  def update_conversation_attribute(key, value)
    @state_manager.set_attribute(key, value)
  end

  def increment_retry_count
    @state_manager.increment_retry_count
  end

  def reset_retry_count
    @state_manager.reset_retry_count
  end

  def dispatch_keyword_handler(method_name)
    unless ALLOWED_KEYWORD_HANDLERS.include?(method_name)
      log_warn "[Bot] ⛔ Blocked unsafe keyword handler: #{method_name}"
      return
    end

    send(method_name)
  end

  def dispatch_interactive_handler(method_name, interactive_data)
    unless ALLOWED_INTERACTIVE_HANDLERS.include?(method_name)
      log_warn "[Bot] ⛔ Blocked unsafe interactive handler: #{method_name}"
      return
    end

    send(method_name, interactive_data)
  end

  def handle_keyword_message
    return false if @message.content.blank?

    keyword = @message.content.downcase.strip

    # Check if it's a demo keyword (isolated template execution)
    if DEMO_KEYWORDS.key?(keyword)
      handler_method = DEMO_KEYWORDS[keyword]
      state_before = @bot_state
      dispatch_keyword_handler(handler_method)

      # Set special state for large form to handle its response differently.
      # If the handler already changed state (e.g., AHW1 waiting for user input),
      # respect it — don't override with DEMO_MODE.
      if handler_method == :handle_large_form_demo
        update_bot_state('DEMO_MODE_LARGE_FORM')
      elsif @bot_state == state_before
        update_bot_state('DEMO_MODE')
      end
      return true
    end

    # Check if it's a flow control keyword
    if FLOW_CONTROL_KEYWORDS.key?(keyword)
      handler_method = FLOW_CONTROL_KEYWORDS[keyword]
      dispatch_keyword_handler(handler_method)
      return true
    end

    # Fuzzy match fallback — catches typos (e.g. "guittar", "tme picker")
    matched_keyword, handler_method, keyword_type = fuzzy_match_keyword(keyword)
    if matched_keyword
      log_info "[Bot] 🔍 Fuzzy match: '#{keyword}' → '#{matched_keyword}'"
      dispatch_keyword_handler(handler_method)
      if keyword_type == :demo
        handler_method == :handle_large_form_demo ? update_bot_state('DEMO_MODE_LARGE_FORM') : update_bot_state('DEMO_MODE')
      end
      return true
    end

    false
  end

  # State machine flow
  def process_state
    log_info "[Bot] ⚙️ process_state - Handling state: #{@bot_state}"
    safe_execute(context: "process_state(#{@bot_state})") do
      # If bot is stopped, don't process state - wait for start/startover keyword
      if @bot_state == 'STOPPED'
        log_info '[Bot] 🛑 Bot is stopped, waiting for start/startover command'
        return
      end

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
        send_text_message("☝️ Please select 'Skip Payment' or 'Try Again' from the options above.")
      when 'AHF2'
        handle_lesson_introduction
      when 'AHF3'
        handle_location_request
      when 'AHG1'
        handle_location_response
      when 'AHG2'
        # Store selection state - waiting for list picker response
        # Interactive handler will process the selection
        send_text_message('☝️ Please select a store from the list above.')
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
        send_text_message('☝️ Please select Yes or No from the options above.')
      when 'AHK1'
        handle_summary
      when 'AHK2'
        handle_final_message
      when 'AHK3'
        handle_register_rich_link
      when 'AHW1'
        handle_wallet_name_input
      when 'AH-restart'
        # Flow restart - go back to welcome
        handle_welcome
      else
        # Unknown state - reset
        log_warn "Unknown bot state: #{@bot_state}, resetting to welcome"
        reset_to_welcome
        handle_welcome
      end
    end # safe_execute
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

    send_text_message("Great to read you are visiting us from #{selection}.")
    update_bot_state('AHA3')
    handle_form_or_name_prompt
  end

  def handle_form_or_name_prompt
    # Check if device supports Apple Messages Forms
    capabilities = @contact.additional_attributes&.dig('apple_messages_capabilities') || ''
    supports_forms = capabilities.include?('FORM')

    if supports_forms
      send_text_message('We would love to know a bit more about you, can you please fill up the following form so we know how to address you? 👇')
      if send_guitar_info_form
        log_info '[Bot] Device supports FORM - Guitar Info Form sent'
        update_bot_state('AHB1') # Wait for form response
      else
        log_info '[Bot] FORM template missing - asking for name via text'
        send_text_message("What's your name?")
        update_bot_state('AHB1_2')
      end
    else
      log_info '[Bot] FORM not supported or template missing - asking for name via text'
      send_text_message("What's your name?")
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

  def extract_address_from_form(form_data)
    return nil if form_data.blank?

    street_section = form_data.find { |section| section['title']&.downcase&.include?('street') || section['title']&.downcase&.include?('address') }
    city_section = form_data.find { |section| section['title']&.downcase == 'city' || section['title']&.downcase&.include?('city') }
    state_section = form_data.find { |section| section['title']&.downcase == 'state' || section['title']&.downcase&.include?('state') }
    zip_section = form_data.find do |section|
      title = section['title']&.downcase
      title&.include?('zip') || title&.include?('postal')
    end

    address = {
      street: street_section&.dig('items', 0, 'value'),
      city: city_section&.dig('items', 0, 'value'),
      state: state_section&.dig('items', 0, 'value'),
      zip: zip_section&.dig('items', 0, 'value')
    }.compact

    address.presence
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
    send_text_message('☝️ Please select either your full name or stage name from the options above.')
  end

  def handle_guitar_list_prompt
    log_info '[Bot] 🎸 handle_guitar_list_prompt called'
    send_text_message('We understand you are interested in purchasing a guitar, here is a selection below. Tap on the bubble to choose one 👇')
    send_guitar_list_picker
    update_bot_state('AHC1')
    log_info '[Bot] 🎸 Guitar list prompt completed, state updated to AHC1'
  end

  # === AHC States (Guitar Selection & Catcher) ===

  def handle_guitar_list_catcher
    retry_count = increment_retry_count

    case retry_count
    when 1
      send_text_message("Looks like we're waiting for you to select a guitar from the list.")
    when 2
      send_text_message('You may also use this menu as well.')
      send_guitar_list_picker
    when 3
      send_text_message("If you find yourself stuck, you may have an overview with the keyword 'Menu'.")
    else
      # After 5+ retries, auto-select every 3rd attempt
      if retry_count >= 5 && (retry_count % 3).zero?
        send_text_message("Okay, we'll just pretend you selected the Martin DC28E Dreadnought.")
        auto_select_guitar('Martin DC28E Dreadnought')
        reset_retry_count
        update_bot_state('AHC2')
        # Don't call handle_ar_introduction directly - let state machine handle it
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

    # Normal flow: update state to AHC2, AR will be sent via process_state
    update_bot_state('AHC2')
    # Don't call handle_ar_introduction directly - let state machine handle it
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

    # NOTE: Removed blocking sleep(15.0) that was causing Rack timeouts
    # Schedule AR question after a short delay so the attachment is visible first
    log_info '[Bot] 🎨 Scheduling AR view question after AR attachment delivery'
    scheduled = schedule_delayed_action(:send_ar_view_question_and_state, delay: 8.0)

    return if scheduled

    # Fallback for Redis/Sidekiq outages: run inline after a short delay
    log_warn '[Bot] ⚠️ AR view question scheduling failed; falling back to inline delay'
    sleep 8.0
    send_ar_view_question_and_state
  end

  def send_ar_view_question_and_state
    log_info '[Bot] 🎨 Sending AR view question after AR attachment delivery'
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
    send_text_message("☝️ Please select 'Yes' or 'No' from the options above to let us know if you saw the AR view.")
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

    if selection_value == '222'
      # No - User didn't see AR view, prompt again and keep waiting
      send_text_message('Try tapping on the image to see the AR preview, then answer the question below.')
      update_bot_state('AHD1')
      send_ar_view_question
      return
    end

    # Yes - skip placement question and proceed directly to Apple Pay
    update_bot_state('AHE2')
    handle_apple_pay_prompt
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
  end

  # Defensive catcher for text input when Quick Reply is expected (AHE1)
  def handle_ar_place_catcher
    log_info '[Bot] 🛡️ handle_ar_place_catcher called - user sent text instead of selecting Quick Reply'
    send_text_message("☝️ Please select 'Yes' or 'No' from the options above to let us know if you'd like to place the guitar in AR.")
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
      send_text_message('Your guitar is waiting — complete the payment to lock in your order!')
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
      send_text_message('☝️ Looks like we\'re waiting for you to select a time from the menu above.')
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

      # Normal flow: send wallet pass then continue
      send_wallet_pass
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
    send_text_message('Thank you for your co-operation, you\'re all set to learn to shred. 🤘 👇')

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
      # Continue directly to photo request
      handle_photo_request
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
    first_name = get_conversation_attribute('customer_name') || 'there'

    send_quick_reply(
      title: 'Share a photo?',
      request_id: 'qr_photo',
      message: "#{first_name}, we would love to see you with your new guitar! Would you like to share a photo?",
      items: [
        { title: 'Yes', value: 'Yes' },
        { title: 'No', value: 'No' }
      ]
    )

    update_bot_state('AHJ1')
  end

  def handle_rich_links
    # Deprecated - silently advance state to avoid duplicate messages
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
      send_text_message('Love it! Go ahead and send us the photo whenever you are ready.')
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
    send_text_message('In Messages for Business, we can also share documents like these ones.')
    send_document('metrics.numbers')

    # Check if we're in demo mode - if so, send PDF and stop
    if @bot_state == 'DEMO_MODE'
      send_document('document.pdf')

      log_info '[Bot] 📄 In DEMO_MODE - documents sent, conversation complete'
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

    # First, send the text message
    send_text_message("#{customer_name}, would you like to learn more about Messages for Business?")

    # Then, send the quick reply without a message body
    send_quick_reply(
      title: 'Learn More?',
      request_id: 'qr_learn_more',
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

    # Send final message immediately - list picker renders in background
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
    log_info '[Bot] 🔄 Starting over - resetting conversation'
    reset_to_welcome
    send_text_message('🔄 Restarting conversation...')
    handle_welcome
  end

  def handle_stop
    log_info '[Bot] 🛑 Stop command received - halting bot flow'
    update_bot_state('STOPPED')
    send_text_message('🛑 Bot stopped. The conversation has been paused.')
    send_text_message("Type 'start' or 'startover' to resume the conversation at any time.")
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
    send_text_message('We understand you are interested in purchasing a guitar, here is a selection below. Tap on the bubble to choose one 👇')
    send_guitar_list_picker
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_time_picker_demo
    # Demo mode: send time picker with default location (Apple Park)
    send_text_message('Here\'s a time picker demo 👇')

    # Use Apple Park as default location for demo
    location = LOCATION_DATABASE['95014']
    send_lesson_time_picker(location)

    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_apple_pay_demo
    # Demo mode: send Apple Pay request with demo item
    send_text_message('Here\'s an Apple Pay payment request 👇')

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
    # Check if device supports Apple Messages Forms
    capabilities = @contact.additional_attributes&.dig('apple_messages_capabilities') || ''
    supports_forms = capabilities.include?('FORM')

    if supports_forms
      send_text_message("Here's our guitar information form 👇")
      unless send_guitar_info_form
        send_text_message("The guitar info form template ('ah_guitar_info_form') is not configured yet. Please create it in the Templates section.")
      end
    else
      send_text_message('Your device does not support FORM, please switch to an iOS device')
    end
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_ar_demo
    # Demo mode: show AR content then ask the same Yes/No questions as the main flow
    send_text_message('Check out our AR experience:')
    send_ar_file
    # State will be set to DEMO_MODE by handle_keyword_message, then
    # send_ar_view_question_and_state transitions to AHD1 so the response is handled.
    scheduled = schedule_delayed_action(:send_ar_view_question_and_state, delay: 8.0)
    return if scheduled

    # Fallback for Redis/Sidekiq outages: run inline after a short delay
    log_warn '[Bot] ⚠️ AR view question scheduling failed in demo; falling back to inline delay'
    sleep 8.0
    send_ar_view_question_and_state
  end

  def handle_large_form_demo
    # Demo mode: send large content form (template 343)
    # Check if device supports Apple Messages Forms
    capabilities = @contact.additional_attributes&.dig('apple_messages_capabilities') || ''
    supports_forms = capabilities.include?('FORM')

    if supports_forms
      send_text_message('Here\'s a form with large content:')
      send_large_content_form
    else
      send_text_message('Your device does not support FORM, please switch to an iOS device')
    end
    # State will be set to DEMO_MODE by handle_keyword_message
  end

  def handle_wallet_demo
    # Demo mode: generate a personalized Apple Wallet pass for the customer.
    # If the customer name is not yet captured, ask for it first (state AHW1).
    if @conversation.custom_attributes&.dig('customer_name').present?
      send_wallet_pass
      # State is set to DEMO_MODE by handle_keyword_message (keyword path)
      # or explicitly below (summary LP path)
    else
      send_text_message("To generate your Guitar Lesson Pickup Pass, what's your name?")
      update_bot_state('AHW1')
    end
  end

  def handle_wallet_name_input
    # AHW1: User replied with their name — store it and generate the pass.
    name = @message.content.strip
    if name.blank?
      send_text_message('Please enter your name to continue.')
      return
    end

    update_conversation_attribute('customer_name', name)
    send_wallet_pass
    update_bot_state('DEMO_MODE')
  end

  def handle_app_clip_demo
    # Demo mode: send App Clip using richLinkDataRef
    send_text_message('📱 App Clip Demo')
    send_text_message('Tap the link below to experience an App Clip!')

    # Send App Clip using richLinkDataRef format
    # This tells Apple MSP to display it as an App Clip invocation instead of a standard rich link
    send_app_clip(url: 'https://chibi.app')

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
    selected_menu_identifier = interactive_data.dig('data', 'reply', 'identifier') ||
                               interactive_data.dig('data', 'listPicker', 'sections')&.find do |section|
                                 section['title'] == 'You Selected'
                               end&.dig('items', 0, 'identifier')
    selected_menu_title = interactive_data.dig('data', 'reply', 'title') ||
                          interactive_data.dig('data', 'listPicker', 'sections')&.find do |section|
                            section['title'] == 'You Selected'
                          end&.dig('items', 0, 'title')
    selection_data = interactive_data['ldtext'] || selected_menu_identifier || selected_menu_title ||
                     interactive_data.dig('data', 'listPicker', 'sections')&.to_json || 'unknown'
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
        '5. Send a Time Picker' => '5',
        '6. Fill in a Form' => '6',
        '7. Send an Image' => '7',
        '8. Send Documents' => '8',
        '9. Authentication' => '9',
        '10. iMessage App' => '10',
        '11. Rich Link Locator' => '11',
        '12. App Clip Example' => '12',
        'Time Picker' => '5',
        'Send a Time Picker' => '5',
        'Schedule a Guitar Lesson' => '5'
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
      # Standard format - extract from listPicker selected section or data.reply
      data = interactive_data['data'] || {}
      list_picker = data['listPicker'] || {}
      sections = list_picker['sections'] || []

      selected_section = sections.find { |section| section['title'] == 'You Selected' }
      selected_item = selected_section&.dig('items', 0)

      # Fallback: in some payloads, selected item is explicitly flagged
      selected_item ||= sections.flat_map { |section| section['items'] || [] }.find { |item| item['selected'] == true }

      selected_item_title = selected_item&.dig('title') || data.dig('reply', 'title')
      selection_identifier = selected_item&.dig('identifier') || data.dig('reply', 'identifier')

      if selection_identifier.present?
        selection_identifier = selection_identifier.to_s
        log_info "[Bot] 📋 Found selected item: #{utf8_encode(selected_item_title)} (identifier: #{selection_identifier})"
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

      identifier_to_id = {
        'act_introduction' => '1',
        'act_list_picker' => '2',
        'act_ar_image' => '3',
        'act_apple_pay' => '4',
        'act_time_picker' => '5',
        'act_form' => '6',
        'act_send_image' => '7',
        'act_documents' => '8',
        'act_authentication' => '9',
        'act_imessage_app' => '10',
        'act_rich_link' => '11',
        'act_app_clip' => '12'
      }

      mapped_id = identifier_to_id[selection_identifier]
      if mapped_id
        log_info "[Bot] 📋 Remapped action identifier from #{selection_identifier} to #{mapped_id}"
        selection_identifier = mapped_id
      end

      # Get the title from ldtext or the captured title
      item_title = interactive_data['ldtext'] || selected_item_title

      if item_title.present? && !/^\d{1,2}$/.match?(selection_identifier)
        log_info "[Bot] 📋 Found title for mapping: #{utf8_encode(item_title)}"

        # Map title to identifier
        title_to_id = {
          '1. Introduction with Intent ID' => '1',
          '2. Send a List Picker' => '2',
          '3. Receive an AR Image' => '3',
          '4. Apple Pay' => '4',
          '5. Send a Time Picker' => '5',
          '6. Fill in a Form' => '6',
          '7. Send an Image' => '7',
          '8. Send Documents' => '8',
          '9. Authentication' => '9',
          '10. iMessage App' => '10',
          '11. Rich Link Locator' => '11',
          '12. App Clip Example' => '12',
          'Time Picker' => '5',
          'Send a Time Picker' => '5',
          'Schedule a Guitar Lesson' => '5'
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
      # 5. Send a Time Picker
      log_info '[Bot] 📋 Menu: Send a Time Picker'
      handle_time_picker_demo
      update_bot_state('DEMO_MODE')
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
      # 9. Authentication
      log_info '[Bot] 📋 Menu: Authentication'
      handle_authentication_menu
    when '10'
      # 10. iMessage App
      log_info '[Bot] 📋 Menu: iMessage App'
      send_text_message('📱 iMessage App Demo')
      send_text_message('This feature demonstrates custom iMessage app extensions.')
      handle_imessage_app
      update_bot_state('DEMO_MODE')
    when '11'
      # 11. Rich Link Locator
      log_info '[Bot] 📋 Menu: Rich Link Locator'
      send_text_message('Here\'s a rich link demo:')
      send_apple_messages_rich_link
      update_bot_state('DEMO_MODE')
    when '12'
      # 12. App Clip Example
      log_info '[Bot] 📋 Menu: App Clip Example'
      handle_app_clip_demo
      update_bot_state('DEMO_MODE')
    else
      log_warn "[Bot] ❌ Unknown menu selection identifier: '#{selection_identifier}'"
      log_warn "[Bot] ❌ This should be a number 1-12, got: #{selection_identifier.class} with value #{utf8_encode(selection_identifier).inspect}"
      send_text_message('Invalid selection. Type \'menu\' to try again.')
      update_bot_state('DEMO_MODE')
    end
  end

  def handle_summary_selection(interactive_data)
    log_info '[Bot] 📋 handle_summary_selection called'

    # Extract selected item identifier from list picker response
    identifier = extract_summary_identifier(interactive_data)
    log_info "[Bot] 📋 Summary selection identifier: #{identifier.inspect}"

    case identifier
    when '1' # Apple Pay
      send_text_message('Here\'s our Apple Pay demo:')
      handle_apple_pay_demo
    when '2' # Apple Wallet
      send_text_message('🍎 Here\'s your Apple Wallet Guitar Lesson Pickup Pass:')
      handle_wallet_demo
    when '3' # AR Experience
      send_text_message('Here\'s our AR experience demo:')
      handle_ar_demo
    when '4' # Authentication
      handle_authentication_menu
    when '5' # File Sharing
      send_text_message('Document sharing demo:')
      handle_documents_intro
    when '6' # iMessage Apps
      send_text_message('📱 iMessage App Demo')
      handle_imessage_app
      update_bot_state('DEMO_MODE')
    when '7' # List Picker
      handle_list_picker_demo
    when '8' # Media Sharing
      send_text_message('📸 Media Sharing lets customers send photos and videos directly in the conversation. Try sending us a photo!')
      update_bot_state('DEMO_MODE')
    when '9' # QR Code
      send_text_message('📷 QR Code scanning lets customers quickly capture and share QR codes within the Messages conversation.')
      update_bot_state('DEMO_MODE')
    when '10' # Quick Type
      send_text_message('⌨️ Quick Type provides intelligent reply suggestions based on conversation context, helping customers respond faster.')
      update_bot_state('DEMO_MODE')
    when '11', '12' # Rich Link Locator / Rich Links
      send_text_message('Here\'s a rich link demo:')
      send_apple_messages_rich_link
      update_bot_state('DEMO_MODE')
    when '13' # Time Picker
      handle_time_picker_demo
    else
      log_warn "[Bot] ❌ Unknown summary selection identifier: #{identifier.inspect}"
      send_text_message("Type 'menu' to explore all features or 'startover' to restart.")
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

      # Schedule the document sending sequence after a brief delay
      schedule_delayed_action(:send_learn_more_documents, delay: 1.0)
    else
      # User doesn't want to learn more - skip to summary
      send_text_message('No problem!')
      update_bot_state('AHK1')
      handle_summary
    end
  end

  def send_learn_more_documents
    # Send documents
    send_text_message('In Messages for Business, we can also share documents like these forms.')
    send_document('metrics.numbers')
    send_document('document.pdf')

    # Schedule rich link display after documents have time to upload and deliver
    schedule_delayed_action(:show_rich_link_and_summary, delay: 6.0)
  end

  def show_rich_link_and_summary
    # Show rich link (handle_rich_link_display sends its own intro message)
    handle_rich_link_display

    # Schedule final message and summary after rich link is displayed
    schedule_delayed_action(:send_final_learn_more_message, delay: 1.0)
  end

  def send_final_learn_more_message
    send_text_message('Please connect with your Apple rep for more information.')
    update_bot_state('AHK1')
    handle_summary
  end

  # === Helper Methods ===

  def schedule_delayed_action(method_name, delay:)
    return false unless method_name.present?

    log_info "[Bot] ⏳ Scheduling delayed action '#{method_name}' in #{delay}s for conversation #{@conversation.id}"
    AppleMessagesForBusiness::BotDelayedActionJob.set(wait: delay.seconds).perform_later(
      conversation_id: @conversation.id,
      method_name: method_name.to_s
    )
    true
  rescue StandardError => e
    Rails.logger.error utf8_encode("[Bot] ❌ Failed to schedule delayed action #{method_name}: #{e.message}")
    Rails.logger.error utf8_encode(e.backtrace.join("\n"))
    false
  end

  # === Delegation to BotMessageSender ===
  # All implementations live in BotMessageSender; these wrappers keep handler
  # methods in the orchestrator unchanged.

  def send_text_message(content)
    @sender.send_text_message(content)
  end

  def send_quick_reply(**)
    @sender.send_quick_reply(**)
  end

  def send_ar_view_question
    @sender.send_ar_view_question
  end

  def send_ar_place_question
    @sender.send_ar_place_question
  end

  def send_ar_file
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      name: 'ah_ar_guitar'
    )

    unless template
      send_text_message('[AR File: Template not found]')
      return
    end

    @sender.send_ar_file
  end

  def send_document(filename)
    @sender.send_document(filename)
  end

  def send_rich_link(**)
    @sender.send_rich_link(**)
  end

  def send_app_clip(**)
    @sender.send_app_clip(**)
  end

  def send_apple_messages_rich_link
    @sender.send_apple_messages_rich_link
  end

  def send_imessage_app
    @sender.send_imessage_app
  end

  def send_wallet_pass
    @sender.send_wallet_pass
  end

  def send_delivery_confirmation(address_data, customer_name = nil)
    @sender.send_delivery_confirmation(address_data, customer_name)
  end

  def send_guitar_list_picker
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      name: 'ah_guitar_list_picker'
    )

    unless template
      send_text_message('Guitar selection temporarily unavailable.')
      return
    end

    @sender.send_guitar_list_picker
  end

  def send_large_content_form
    @sender.send_large_content_form
  end

  def send_summary_list_picker
    @sender.send_summary_list_picker
  end

  def send_menu_list_picker
    @sender.send_menu_list_picker
  end

  def send_lesson_time_picker(location)
    @sender.send_lesson_time_picker(location)
    # Schedule a proactive 10-second reminder if this is a fresh send (not a retry already in AHH1)
    schedule_delayed_action(:send_time_picker_waiting_reminder, delay: 10.0) unless @bot_state == 'AHH1'
  end

  def send_time_picker_waiting_reminder
    # Only fire if the user hasn't already triggered the catcher (retry_count == 0)
    return unless @bot_state == 'AHH1'
    return if (get_conversation_attribute('retry_count') || 0) > 0

    send_text_message("☝️ Looks like we're waiting for you to select a time from the menu above.")
    increment_retry_count # Prevent catcher's `when 1` from sending the same message again
  end

  def send_store_quick_reply(stores, user_coordinates)
    @sender.send_store_quick_reply(stores, user_coordinates)
  end

  def send_store_selection_list_picker(stores, user_coordinates)
    @sender.send_store_selection_list_picker(stores, user_coordinates)
  end

  def send_apple_pay_request(guitar_name)
    @sender.send_apple_pay_request(guitar_name)
  end

  def send_oauth_authentication(provider)
    @sender.send_oauth_authentication(provider)
  end

  def fetch_and_encode_images(identifiers)
    @sender.fetch_and_encode_images(identifiers)
  end

  def with_typing_indicator(&)
    @sender.with_typing_indicator(&)
  end

  # Returns true if the form was sent successfully, false if template not found.
  # Callers are responsible for fallback behaviour.
  def send_guitar_info_form
    return if @sender.send_guitar_info_form

    handle_guitar_list_prompt
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

  def handle_imessage_app(_interactive_data = nil)
    log_info '[Bot] 🎵 handle_imessage_app called - Sending Shazam extension'
    @sender.send_imessage_app
  end

  # === OAuth Authentication Handlers ===

  def handle_authentication_menu
    # TEMPORARY: Skip provider selection and go directly to LinkedIn OAuth
    # Other providers (Google, Facebook) are temporarily disabled
    log_info '[Bot] 🔐 Authentication menu - defaulting to LinkedIn OAuth'
    send_text_message('🔐 OAuth Authentication Demo')

    # Directly call LinkedIn OAuth handler
    handle_linkedin_oauth_demo

    # ORIGINAL CODE (commented out for temporary LinkedIn-only flow):
    # send_text_message('Choose which provider you\'d like to authenticate with:')
    # send_quick_reply(
    #   title: 'Select OAuth Provider',
    #   request_id: 'qr_oauth_provider',
    #   items: [
    #     { title: 'LinkedIn', value: 'linkedin' },
    #     { title: 'Google', value: 'google' },
    #     { title: 'Facebook', value: 'facebook' }
    #   ]
    # )
    # update_bot_state('DEMO_MODE_AUTH_PROVIDER')
  end

  def handle_oauth_provider_selection(interactive_data)
    log_info '[Bot] 🔐 handle_oauth_provider_selection called'

    # Extract selected provider - handle both standard format and NSKeyedArchiver
    provider = if interactive_data['$archiver'] == 'NSKeyedArchiver'
                 # NSKeyedArchiver format - extract from $objects array
                 objects = interactive_data['$objects'] || []
                 objects.find { |obj| obj.is_a?(String) && obj.match?(/linkedin|google|facebook/i) }
               else
                 # Standard quick reply format
                 quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
                 selected_index = quick_reply_data['selectedIndex']
                 items = quick_reply_data['items'] || []

                 items[selected_index]&.fetch('title', nil) if selected_index
               end

    log_info "[Bot] 🔐 Selected provider: #{utf8_encode(provider)}"

    case provider&.downcase
    when 'linkedin'
      handle_linkedin_oauth_demo
    when 'google'
      handle_google_oauth_demo
    when 'facebook'
      handle_facebook_oauth_demo
    else
      send_text_message('Invalid provider selected. Type \'menu\' to try again.')
    end
  end

  def handle_linkedin_oauth_demo
    log_info '[Bot] 🔗 LinkedIn OAuth demo'

    # Check if LinkedIn OAuth is enabled for this inbox
    unless @conversation.inbox.channel.oauth2_provider_enabled?('linkedin')
      send_text_message('❌ LinkedIn OAuth is not enabled for this inbox.')
      send_text_message('Please configure LinkedIn OAuth in inbox settings.')
      update_bot_state('DEMO_MODE')
      return
    end

    send_text_message('🔗 LinkedIn Authentication')
    send_text_message('Please authenticate with your LinkedIn account to continue.')

    send_oauth_authentication('linkedin')
    update_bot_state('DEMO_MODE')
  end

  def handle_google_oauth_demo
    log_info '[Bot] 🔵 Google OAuth demo'

    # Check if Google OAuth is enabled for this inbox
    unless @conversation.inbox.channel.oauth2_provider_enabled?('google')
      send_text_message('❌ Google OAuth is not enabled for this inbox.')
      send_text_message('Please configure Google OAuth in inbox settings.')
      update_bot_state('DEMO_MODE')
      return
    end

    send_text_message('🔵 Google Authentication')
    send_text_message('Please authenticate with your Google account to continue.')

    send_oauth_authentication('google')
    update_bot_state('DEMO_MODE')
  end

  def handle_facebook_oauth_demo
    log_info '[Bot] 🔷 Facebook OAuth demo'

    # Check if Facebook OAuth is enabled for this inbox
    unless @conversation.inbox.channel.oauth2_provider_enabled?('facebook')
      send_text_message('❌ Facebook OAuth is not enabled for this inbox.')
      send_text_message('Please configure Facebook OAuth in inbox settings.')
      update_bot_state('DEMO_MODE')
      return
    end

    send_text_message('🔷 Facebook Authentication')
    send_text_message('Please authenticate with your Facebook account to continue.')

    send_oauth_authentication('facebook')
    update_bot_state('DEMO_MODE')
  end

  # === Fuzzy keyword matching ===

  # Extracts the selected item identifier from a summary list picker response.
  # Handles standard listPicker format, ldtext (IDR), and NSKeyedArchiver.
  def extract_summary_identifier(interactive_data)
    # IDR/ldtext resolved format
    return interactive_data['ldtext'].strip if interactive_data['ldtext'].present?

    data = interactive_data['data'] || {}
    list_picker = data['listPicker'] || {}
    sections = list_picker['sections'] || []

    # Standard format: look for the 'You Selected' echo section first
    selected_section = sections.find { |s| s['title'] == 'You Selected' }
    selected_item = selected_section&.dig('items', 0)
    # Fallback: find the item explicitly flagged as selected
    selected_item ||= sections.flat_map { |s| s['items'] || [] }.find { |item| item['selected'] == true }

    identifier = selected_item&.dig('identifier')
    return identifier.to_s if identifier.present?

    # NSKeyedArchiver format: find a short numeric string in $objects
    if interactive_data['$archiver'] == 'NSKeyedArchiver'
      objects = interactive_data['$objects'] || []
      return objects.find { |obj| obj.is_a?(String) && obj.match?(/^\d{1,2}$/) }
    end

    nil
  end

  # Returns [matched_keyword, handler_method, :demo|:flow_control] or nil
  def fuzzy_match_keyword(input)
    best = nil
    best_distance = Float::INFINITY

    { demo: DEMO_KEYWORDS, flow_control: FLOW_CONTROL_KEYWORDS }.each do |type, keywords|
      keywords.each do |keyword, handler|
        next if keyword.length < 4 # skip very short keywords to avoid false positives

        max_distance = keyword.length <= 6 ? 1 : 2
        dist = levenshtein_distance(input, keyword)

        if dist <= max_distance && dist < best_distance
          best_distance = dist
          best = [keyword, handler, type]
        end
      end
    end

    best
  end

  def levenshtein_distance(str1, str2)
    m = str1.length
    n = str2.length
    d = Array.new(m + 1) { Array.new(n + 1, 0) }
    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }
    (1..m).each do |i|
      (1..n).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
      end
    end
    d[m][n]
  end
end
