# frozen_string_literal: true

class AppleMessagesForBusiness::AcousticHouseBotService
  IDLE_TIMEOUT = 30.minutes

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

  # Interactive response routing
  INTERACTIVE_HANDLERS = {
    'qr_travel' => :handle_region_selection,
    'qr_name' => :handle_name_selection,
    'lp_guitar_0319' => :handle_guitar_selection,
    'applepay_1018' => :handle_apple_pay_response,
    'time_0319' => :handle_time_picker_response,
    'qr_view_ar' => :handle_ar_view_response,
    'qr_place_ar' => :handle_ar_place_response,
    'qr_continue' => :handle_continue_response,
    'qr_photo' => :handle_photo_response,
    'qr_learn_more' => :handle_learn_more_response,
    'lp_menu_0319' => :handle_menu_selection
  }.freeze

  def initialize(conversation, message)
    @conversation = conversation
    @message = message
    @contact = conversation.contact
    @bot_state = get_bot_state
    @lang = detect_language
  end

  def process_message
    Rails.logger.info "[Bot] 🔄 process_message - Current state: #{@bot_state}, Message content: #{@message.content&.truncate(50)}"
    Rails.logger.info "[Bot] 🔄 Message content_type: #{@message.content_type}"
    sanitized_attrs = LogSanitizerService.sanitize_for_log(@message.content_attributes)
    Rails.logger.info "[Bot] 🔄 Message content_attributes: #{sanitized_attrs.inspect}"

    # Check for timeout - restart if idle > 30 minutes
    if conversation_timed_out?
      reset_to_welcome
      return process_state
    end

    # Handle attachments (photos, documents)
    if @message.attachments.present?
      handle_received_attachment
      return
    end

    # Handle text message keywords
    return if handle_keyword_message

    # Handle form responses by content_type (forms don't have custom identifiers)
    if @message.content_type == 'apple_form_response'
      Rails.logger.info '[Bot] ✅ Detected form response, calling handle_form_response'
      handle_form_response
      return
    end

    # Handle state-based flow
    process_state
  end

  def process_interactive_response(interactive_data)
    Rails.logger.info '[Bot] 🎯 process_interactive_response called'
    Rails.logger.info "[Bot] 🎯 Interactive data: #{interactive_data.inspect}"

    # For quick replies, Apple uses 'selectedIdentifier' (our custom identifier)
    # For other types (list picker, time picker), use 'requestIdentifier'
    data = interactive_data['data'] || {}

    request_id = if data['quick-reply']
                   # Quick reply uses selectedIdentifier (the identifier we set on items)
                   selected_id = data.dig('quick-reply', 'selectedIdentifier')
                   Rails.logger.info "[Bot] 🎯 Quick reply detected - selectedIdentifier: #{selected_id}"
                   selected_id
                 else
                   # Other interactive types use requestIdentifier
                   req_id = data['requestIdentifier']
                   Rails.logger.info "[Bot] 🎯 Interactive type detected - requestIdentifier: #{req_id}"
                   req_id
                 end

    Rails.logger.info "[Bot] 🎯 Processing interactive response - requestId: #{request_id}"
    Rails.logger.info "[Bot] 📋 Interactive data keys: #{interactive_data.keys.inspect}"
    Rails.logger.info "[Bot] 📋 Data keys: #{data.keys.inspect}"

    handler_method = INTERACTIVE_HANDLERS[request_id]
    if handler_method
      Rails.logger.info "[Bot] ✅ Found handler: #{handler_method}"
      send(handler_method, interactive_data)
    else
      Rails.logger.warn "[Bot] ❌ No handler for requestId: #{request_id}"
      Rails.logger.warn "[Bot] 📝 Available handlers: #{INTERACTIVE_HANDLERS.keys.inspect}"
    end
  end

  private

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
    handler_method = KEYWORD_HANDLERS[keyword]

    if handler_method
      send(handler_method)
      return true
    end

    false
  end

  # State machine flow
  def process_state
    Rails.logger.info "[Bot] ⚙️ process_state - Handling state: #{@bot_state}"
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
    when 'AHJ2'
      handle_documents_intro
    when 'AHJ3'
      handle_pdf_document
    when 'AHJ4'
      handle_learn_more_prompt
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
      Rails.logger.warn "Unknown bot state: #{@bot_state}, resetting to welcome"
      reset_to_welcome
      handle_welcome
    end
  end

  # === AHA States (Welcome Flow) ===

  def handle_welcome
    Rails.logger.info "[Bot] 🎯 handle_welcome called - State: #{@bot_state}"
    send_text_message('Thank you for contacting Acoustic Bot Prod.')
    send_text_message("Let's help you find your next guitar 🎸.")
    # Send region prompt immediately, update state in handle_region_prompt
    handle_region_prompt
  end

  def handle_region_prompt
    Rails.logger.info "[Bot] 🎯 handle_region_prompt called - State: #{@bot_state}"
    Rails.logger.info "[Bot] 🎯 Called from: #{caller[0..3].join("\n")}"
    # Update state here instead of in handle_welcome
    update_bot_state('AHA2') if @bot_state == 'AHA1'

    send_text_message('Which region are you traveling from?')
    send_quick_reply(
      title: 'Select Region',
      request_id: 'qr_travel',
      items: [
        { title: 'Americas', value: 'Americas' },
        { title: 'Europe', value: 'Europe' },
        { title: 'Asia Pacific', value: 'Asia Pacific' }
      ]
    )
  end

  def handle_region_selection(interactive_data)
    # Extract selected option from Apple quick reply format
    quick_reply_data = interactive_data.dig('data', 'quick-reply') || {}
    selected_index = quick_reply_data['selectedIndex']
    items = quick_reply_data['items'] || []

    selection = items[selected_index]&.fetch('title', nil) if selected_index

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
      Rails.logger.info '[Bot] Device supports FORM - sending Apple Messages Form'
      send_guitar_info_form
      update_bot_state('AHB1') # Wait for form response
    else
      Rails.logger.info '[Bot] Device does not support FORM - skipping to guitar list'
      send_text_message('Tell us about yourself!')
      # Skip form and go directly to guitar list
      update_bot_state('AHB3')
      handle_guitar_list_prompt
    end
  end

  # === AHB States (Name & Form Flow) ===

  def handle_form_response
    # Parse form response from content_attributes
    form_data = @message.content_attributes.dig('form_response', 'selections') || []

    Rails.logger.info "[Bot] 📝 Parsing form response with #{form_data.length} selections"

    # Extract customer name (Full Name field - index 1)
    full_name_section = form_data[1]
    customer_name = full_name_section&.dig('items', 0, 'value')

    # Extract stage name (Stage Name field - index 2)
    stage_name_section = form_data[2]
    stage_name = stage_name_section&.dig('items', 0, 'value')

    # Store in conversation attributes
    update_conversation_attribute('customer_name', customer_name) if customer_name.present?
    update_conversation_attribute('stage_name', stage_name) if stage_name.present?

    Rails.logger.info "[Bot] ✅ Form parsed - customer_name: #{customer_name}, stage_name: #{stage_name}"

    # Thank user and continue to guitar list
    send_text_message("Thank you#{customer_name.present? ? ", #{customer_name}" : ''}!")

    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def handle_text_name_input
    # Handle plain text name input
    customer_name = @message.content.strip
    update_conversation_attribute('customer_name', customer_name)
    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def handle_name_preference_selection
    # TODO: Handle name preference selection (real name vs stage name)
    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def handle_guitar_list_prompt
    Rails.logger.info '[Bot] 🎸 handle_guitar_list_prompt called'
    send_text_message('Here are some amazing guitars:')
    send_guitar_list_picker
    update_bot_state('AHC1')
    Rails.logger.info '[Bot] 🎸 Guitar list prompt completed, state updated to AHC1'
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
    selection = interactive_data.dig('data', 'reply', 'title')
    update_conversation_attribute('selected_guitar', selection)
    reset_retry_count

    send_text_message("Great choice! You selected #{selection}.")
    update_bot_state('AHC2')
    handle_ar_introduction
  end

  def auto_select_guitar(guitar_name)
    update_conversation_attribute('selected_guitar', guitar_name)
  end

  # === AHC States (AR Introduction & Questions) - Phase 2 ===

  def handle_ar_introduction
    # AHC2: Send AR file
    send_text_message('Just in. We have this cool Stratocaster. Check it out!!!')
    send_ar_file
    update_bot_state('AHC3')

    # Wait 20 seconds then proceed to AHC3
    # Note: In production, this would be a scheduled job
    # For now, we'll proceed immediately
    handle_ar_first_question
  end

  def handle_ar_first_question
    # AHC3: First AR question
    send_text_message('Did you click on the image and see the 3D augmented reality view of the guitar?')
    send_ar_view_question
    update_bot_state('AHD1')
  end

  def handle_ar_second_question
    # This is now handled by handle_ar_view_response (AHD1)
  end

  def handle_ar_view_response(interactive_data)
    # AHD1: AR view response
    selection_value = interactive_data.dig('data', 'reply', 'identifier')

    if selection_value == '111' # Yes
      # User clicked and saw AR view
      customer_name = get_conversation_attribute('customer_name') || 'there'
      send_text_message("Awesome! #{customer_name} did you select AR from the top of the image and set it down in front of you?")
    else
      # User didn't see AR view
      send_text_message('Try tapping on the image to see the AR image of the guitar!')
      send_text_message('Did you select AR from the top of the image and set it down in front of you?')
    end
    send_ar_place_question

    update_bot_state('AHE1')
  end

  def handle_ar_place_response(interactive_data)
    # AHE1: AR place response
    selection_value = interactive_data.dig('data', 'reply', 'identifier')

    send_text_message('Try tapping on the image to see the AR image of the guitar!') if selection_value == '222' # No - they didn't place AR

    # Always proceed to Apple Pay
    guitar_name = get_conversation_attribute('selected_guitar') || 'guitar'
    send_text_message("Great, let's buy your new #{guitar_name}.")

    update_bot_state('AHE2')
    handle_apple_pay_prompt
  end

  def handle_apple_pay_prompt
    # AHE2: Send Apple Pay request
    guitar_name = get_conversation_attribute('selected_guitar') || 'guitar'

    result = send_apple_pay_request(guitar_name)

    if result[:success]
      update_bot_state('AHF1')
    else
      send_text_message('We are experiencing some technical difficulties with our Apple Pay service. We apologize for this inconvenience and we are working on a fix.')
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
    payment_status = interactive_data.dig('data', 'payment', 'status')

    send_text_message('Payment received! (Just kidding - this is a demo)') if payment_status == 'success'

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
      send_text_message('We can find the closest location for you, just message us your zipcode. Where are you?')
    end

    update_bot_state('AHG1')
  end

  def handle_location_response
    # AHG1: Process location input (zipcode or Apple Maps link)
    user_message = @message.content.strip

    # Check if Apple Maps link
    if user_message.include?('maps.apple.com')
      match = user_message.match(/ll=([-\d.]+),([-\d.]+)/)

      if match
        location = {
          name: 'Selected Location',
          latitude: match[1].to_f,
          longitude: match[2].to_f,
          timezone_offset: '-0800'
        }

        send_text_message("Great! Here are available times at #{location[:name]}.")
        send_lesson_time_picker(location)
        update_bot_state('AHH1')
        reset_retry_count
        return
      end
    end

    # Try geocoding zipcode (MVP: hardcoded lookup)
    location = geocode_zipcode(user_message)

    send_text_message('We were unable to locate your nearest Apple Store, so here are the available times at Apple Park.')
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
    # Handle time picker selection
    selected_timeslot = _interactive_data.dig('data', 'timeslot')

    if selected_timeslot
      update_conversation_attribute('selected_timeslot', selected_timeslot)
      reset_retry_count
      update_bot_state('AHH2')
      handle_continue_prompt
    else
      # Invalid response, retry
      handle_time_picker_catcher
    end
  end

  def handle_continue_prompt
    # AHH2: Ask if user wants to continue
    send_text_message('Thank you for your co-operation, you\'re all set to learn to shred. 🤘')
    send_text_message('Shall we continue?')

    send_quick_reply(
      title: 'Shall we continue?',
      request_id: 'qr_continue',
      items: [
        { title: 'Yes', value: 'Yes' },
        { title: 'No', value: 'No' }
      ]
    )

    update_bot_state('AHI1')
  end

  def handle_continue_response(_interactive_data)
    # AHI1: Route based on continue response
    selection_identifier = _interactive_data.dig('data', 'reply', 'identifier')

    if selection_identifier == '222' # No
      # Skip to learn more (Phase 4)
      update_bot_state('AHK1')
      handle_summary
    else
      # Continue to rich links (AHI2)
      send_text_message('There\'s so much more you can do like sharing beautiful links to your website:')
      update_bot_state('AHI2')
      handle_rich_link_display
    end
  end

  def handle_rich_link_display
    # AHI2: Send rich link
    send_apple_messages_rich_link

    update_bot_state('AHI3')
    handle_photo_intro
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
    send_text_message("You can send us one too!!! #{first_name} will you share a picture of your favorite food or place to eat?")

    send_quick_reply(
      title: 'Will you share a picture?',
      request_id: 'qr_photo',
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

  def handle_photo_response
    # AHJ1: Photo invitation
    send_text_message('Awesome! We will hang tight while you send us your fav.')
    update_bot_state('AHJ2')
    handle_documents_intro
  end

  def handle_documents_intro
    # AHJ2: Send metrics.numbers
    send_text_message('In Messages for Business, we can also share documents like these forms.')
    send_document('metrics.numbers')
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
    send_text_message("#{customer_name}, would you like to learn more about Messages for Business?")
    send_quick_reply(
      title: 'Learn More?',
      request_id: 'qr_learn_more',
      items: [
        { title: 'Yes', value: 'yes' },
        { title: 'No', value: 'no' }
      ]
    )
    update_bot_state('AHK1')
  end

  # === AHK States (Summary & Final Rich Link) ===

  def handle_summary
    # AHK1: Summary list picker
    send_summary_list_picker
    update_bot_state('AHK2')
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

    content_type = @message.content_type

    if content_type&.start_with?('image/')
      send_text_message('Awesome photo! #photooftheday #instadaily')
      update_bot_state('AHJ2')
      handle_documents_intro
    elsif content_type == 'application/vnd.apple.numbers'
      send_text_message('Thank you for the spreadsheet.')
    end
  end

  # === Keyword Handlers ===

  def handle_menu
    send_text_message('🎸 Acoustic House Bot Menu')
    send_text_message('Commands: startover, summary, guitar, time picker, apple pay, form, ar')
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

  def handle_list_picker_demo
    send_text_message('Here are some amazing guitars:')
    send_guitar_list_picker
    update_bot_state('AHC1') # Set state to wait for guitar selection
  end

  def handle_time_picker_demo
    send_text_message('Time picker demo coming soon!')
  end

  def handle_apple_pay_demo
    send_text_message('Apple Pay demo coming soon!')
  end

  def handle_form_demo
    send_text_message('Form demo coming soon!')
  end

  def handle_ar_demo
    send_text_message('AR demo coming soon!')
  end

  def handle_menu_selection(_interactive_data)
    # TODO: Implement menu selection
  end

  def handle_learn_more_response(interactive_data)
    selection = interactive_data.dig('data', 'reply', 'title')

    send_text_message('Please connect with your Apple rep for more information.') if selection == 'Yes'

    # Always show summary regardless of selection
    send_text_message("We've thrown a handful of Messages for Business features at you today. Check out what you saw.")
    update_bot_state('AHK1')
    handle_summary
  end

  # === Helper Methods ===

  def send_text_message(content)
    Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: content
      }
    ).perform
  end

  def send_quick_reply(title:, request_id:, items:)
    Rails.logger.info "[Bot] 📤 Sending quick reply: #{title} (request_id: #{request_id})"
    Rails.logger.info "[Bot] 📤 Called from: #{caller[0..3].join("\n")}"
    # Create outgoing message with quick reply content
    # NOTE: SendReplyJob will automatically send this to Apple MSP via after_create callback
    Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
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
      }
    ).perform

    # Message will be automatically sent by SendReplyJob (after_create callback)
    # No need to manually call SendQuickReplyService
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send quick reply: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def send_guitar_list_picker
    # Get guitar list picker template by ID
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 321
    )

    unless template
      Rails.logger.error '[Bot] Guitar List Picker template (ID: 321) not found'
      send_text_message('Guitar selection temporarily unavailable.')
      return
    end

    Rails.logger.info "[Bot] Sending Guitar List Picker (ID: 321, Name: #{template.name})"

    # Extract list picker data from template
    template_attrs = template.metadata.dig('apple_message_content', 'content_attributes') || {}
    list_picker_data = template_attrs['list_picker'] || {}
    sections = list_picker_data['sections']
    received_message = template_attrs['received_message'] || {}
    reply_message = template_attrs['reply_message'] || {}

    if sections.blank?
      Rails.logger.error '[Bot] Guitar List Picker template has no sections'
      send_text_message('Guitar selection temporarily unavailable.')
      return
    end

    # Fix invalid style values - change "default" to "large"
    sections = sections.map do |section|
      section_copy = section.deep_dup
      if section_copy['items'].present?
        section_copy['items'].each do |item|
          item['style'] = 'large' if item['style'] == 'default' || item['style'].blank?
        end
      end
      section_copy
    end

    # Collect all image identifiers used in the sections and messages
    item_image_identifiers = sections.flat_map do |section|
      (section['items'] || []).map { |item| item['image_identifier'] }
    end.compact

    Rails.logger.info "[Bot] 🎸 Item image identifiers from template: #{item_image_identifiers.inspect}"

    # Also collect image identifiers from received/reply messages
    received_image_id = received_message['image_identifier']
    reply_image_id = reply_message['image_identifier']

    all_identifiers = (item_image_identifiers + [received_image_id, reply_image_id]).compact.uniq

    Rails.logger.info "[Bot] 🎸 All image identifiers: #{all_identifiers.inspect}"

    # Fetch and encode images from ActiveStorage
    images = fetch_and_encode_images(all_identifiers)

    Rails.logger.info "[Bot] 🎸 Encoded #{images.length} images"

    # Build content attributes with all components
    content_attrs = {
      'sections' => sections,
      'images' => images,
      'request_identifier' => 'lp_guitar_0319'
    }

    # Add received_message fields (flattened with received_ prefix)
    if received_message.present?
      content_attrs['received_title'] = received_message['title']
      content_attrs['received_subtitle'] = received_message['subtitle']
      content_attrs['received_image_identifier'] = received_message['image_identifier']
      content_attrs['received_style'] = received_message['style']
    end

    # Add reply_message fields (flattened with reply_ prefix)
    if reply_message.present?
      content_attrs['reply_title'] = reply_message['title']
      content_attrs['reply_subtitle'] = reply_message['subtitle']
      content_attrs['reply_image_identifier'] = reply_message['image_identifier']
      content_attrs['reply_style'] = reply_message['style']
    end

    # Create outgoing message with list picker content including images
    message = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: 'Select a guitar',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      }
    ).perform

    # Use SendListPickerService to send to Apple MSP
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

    AppleMessagesForBusiness::SendListPickerService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    ).perform
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send guitar list picker: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def fetch_and_encode_images(identifiers)
    return [] if identifiers.empty?

    # Fetch AppleListPickerImage records for these identifiers
    inbox_id = @conversation.inbox_id
    picker_images = AppleListPickerImage
                    .where(inbox_id: inbox_id, identifier: identifiers)
                    .includes(image_attachment: :blob)

    Rails.logger.info "[Bot] 🖼️ Looking for images with identifiers: #{identifiers.inspect}"
    Rails.logger.info "[Bot] 🖼️ Found #{picker_images.count} images in ActiveStorage: #{picker_images.map(&:identifier).inspect}"

    # Convert to base64 array format expected by SendListPickerService
    picker_images.filter_map do |picker_image|
      next unless picker_image.image.attached?

      begin
        # Download and encode image as base64
        image_data = picker_image.image.download
        base64_data = Base64.strict_encode64(image_data)

        Rails.logger.info "[Bot] 🖼️ Encoded image: #{picker_image.identifier} (#{(base64_data.length / 1024.0).round(2)} KB)"

        {
          'identifier' => picker_image.identifier,
          'data' => base64_data,
          'description' => picker_image.description || ''
        }
      rescue StandardError => e
        Rails.logger.error "[Bot] Failed to encode image #{picker_image.identifier}: #{e.message}"
        nil
      end
    end
  end

  def send_guitar_info_form
    # Use the specific form template by ID
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      id: 343
    )

    unless template
      Rails.logger.error '[Bot] Guitar Info Form template (ID: 343) not found - falling back to guitar list'
      # Fallback: skip to guitar list if form template doesn't exist
      update_bot_state('AHB3')
      handle_guitar_list_prompt
      return
    end

    Rails.logger.info "[Bot] Sending Guitar Info Form (ID: 343, Name: #{template.name})"

    # Extract content attributes and add request_identifier
    content_attrs = template.metadata.dig('apple_message_content', 'content_attributes') || {}
    content_attrs['request_identifier'] = 'form_0343' if content_attrs['request_identifier'].blank?

    # Create outgoing message with form content
    Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: template.metadata.dig('apple_message_content', 'title') || 'Guitar Info Form',
        content_type: 'apple_form',
        content_attributes: content_attrs
      }
    ).perform

    # Form will be automatically sent via SendReplyJob callback
    Rails.logger.info '[Bot] Guitar Info Form sent successfully'
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send guitar info form: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Fallback to guitar list on error
    update_bot_state('AHB3')
    handle_guitar_list_prompt
  end

  def send_summary_list_picker
    # Get summary list picker template
    template = MessageTemplate.find_by(
      account_id: @conversation.account_id,
      name: 'Summary List Picker'
    )

    unless template
      Rails.logger.error '[Bot] Summary List Picker template not found'
      send_text_message('Summary temporarily unavailable.')
      return
    end

    # Create outgoing message with list picker content
    content_attrs = template.metadata.dig('apple_message_content', 'content_attributes') || {}
    # Add request_identifier for proper routing (summary list picker doesn't need a handler)
    content_attrs['request_identifier'] = 'lp_summary_0319' if content_attrs['request_identifier'].blank?

    message = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: 'Feature Sheet',
        content_type: 'apple_list_picker',
        content_attributes: content_attrs
      }
    ).perform

    # Use SendListPickerService to send to Apple MSP
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

    AppleMessagesForBusiness::SendListPickerService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    ).perform
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send summary list picker: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def send_ar_file
    # Send stratocaster.usdz file as attachment
    # For Phase 2, we'll use a placeholder approach
    # The actual USDZ file should be stored in ActiveStorage

    # NOTE: In production, you would:
    # 1. Store stratocaster.usdz in ActiveStorage
    # 2. Attach it to a message
    # 3. Send via SendMessageService with attachments

    Rails.logger.info '[Bot] Sending AR file (stratocaster.usdz)'
    send_text_message('[AR File: stratocaster.usdz would be sent here]')

    # TODO: Implement actual AR file sending via ActiveStorage
    # Example:
    # message = Messages::MessageBuilder.new(
    #   bot_user,
    #   @conversation,
    #   {
    #     message_type: :outgoing,
    #     content: '',
    #     attachments: [...]
    #   }
    # ).perform
  end

  def send_ar_view_question
    # Send quick reply asking if user viewed AR
    send_quick_reply(
      title: 'Did you click on the image and see the 3D augmented reality view of the guitar?',
      request_id: 'qr_view_ar',
      items: [
        { title: 'Yes', identifier: '111' },
        { title: 'No', identifier: '222' }
      ]
    )
  end

  def send_ar_place_question
    # Send quick reply asking if user placed AR
    send_quick_reply(
      title: 'Did you select AR from the top of the image and set it down in front of you?',
      request_id: 'qr_place_ar',
      items: [
        { title: 'Yes', identifier: '111' },
        { title: 'No', identifier: '222' }
      ]
    )
  end

  def send_apple_pay_request(guitar_name)
    # Send Apple Pay request for the selected guitar
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

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
      'received_subtitle' => 'test payment'
    }

    AppleMessagesForBusiness::SendApplePayService.new(
      channel: channel,
      destination_id: destination_id,
      payment_data: payment_data
    ).perform
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send Apple Pay request: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  def send_document(filename)
    # This will be implemented to send document files
    # For now, log and return
    Rails.logger.info "[Bot] Would send document: #{filename}"
    # TODO: Implement document sending via ActiveStorage
  end

  def send_rich_link(url:, image_asset:, title:)
    # This will be implemented to send rich links
    # For now, log and return
    Rails.logger.info "[Bot] Would send rich link: #{url} (#{title})"
    # TODO: Implement rich link sending
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

  def bot_user
    @conversation.inbox.channel.try(:bot_user) || @conversation.account.users.first
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

    # Create message with time picker content
    message = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: "Schedule a lesson with your #{guitar}",
        content_type: 'apple_time_picker',
        content_attributes: {
          'request_identifier' => 'time_0319',
          'received_title' => "Schedule a lesson with your #{guitar}",
          'received_subtitle' => location[:name],
          'reply_title' => 'Thank you!',
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
      }
    ).perform

    # Send via SendTimePickerService
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

    AppleMessagesForBusiness::SendTimePickerService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    ).perform
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send time picker: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def send_apple_messages_rich_link
    # Create message with rich link
    message = Messages::MessageBuilder.new(
      bot_user,
      @conversation,
      {
        message_type: :outgoing,
        content: 'https://register.apple.com/resources/messages/messaging-documentation/',
        content_type: 'rich_link',
        content_attributes: {
          'url' => 'https://register.apple.com/resources/messages/messaging-documentation/',
          'title' => 'Apple Messages for Business',
          'image_url' => 'https://register.apple.com/resources/messages/images/hero.png'
        }
      }
    ).perform

    # Send via SendRichLinkService
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

    AppleMessagesForBusiness::SendRichLinkService.new(
      channel: channel,
      destination_id: destination_id,
      message: message
    ).perform
  rescue StandardError => e
    Rails.logger.error "[Bot] Failed to send rich link: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
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

  # Check if template images are available in current inbox
  # Returns hash with missing and available identifiers
  def check_template_images_available(template, inbox_id = nil)
    inbox_id ||= @conversation.inbox_id
    identifiers = template.extract_image_identifiers_from_blocks

    return { available: [], missing: [], all_available: true } if identifiers.empty?

    available = AppleListPickerImage.where(inbox_id: inbox_id, identifier: identifiers).pluck(:identifier)
    missing = identifiers - available

    if missing.any?
      Rails.logger.warn "[Bot] Template #{template.id} missing images in inbox #{inbox_id}: #{missing.inspect}"
      Rails.logger.warn "[Bot] Available images: #{available.inspect}"
    end

    {
      available: available,
      missing: missing,
      all_available: missing.empty?
    }
  end
end
