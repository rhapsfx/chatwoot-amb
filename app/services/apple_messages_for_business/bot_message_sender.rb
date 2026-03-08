# frozen_string_literal: true

module AppleMessagesForBusiness
  # Owns all outgoing message construction and delivery for the bot.
  # Methods here must NOT update bot_state or call handler methods —
  # those concerns belong in AcousticHouseBotService.
  #
  # State-machine constants (TYPING_INDICATORS_ENABLED, TYPING_INDICATOR_DELAY)
  # are read from AcousticHouseBotService so behaviour stays consistent.
  class BotMessageSender
    include BotLogging

    # Defer constant lookup to avoid load-order dependency on AcousticHouseBotService.
    def typing_indicators_enabled?
      AppleMessagesForBusiness::AcousticHouseBotService::TYPING_INDICATORS_ENABLED
    end

    def typing_indicator_delay
      AppleMessagesForBusiness::AcousticHouseBotService::TYPING_INDICATOR_DELAY
    end

    def initialize(conversation)
      @conversation = conversation
    end

    # === Core message senders ===

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

      send_text_message(message) if message.present?

      with_typing_indicator do
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
    rescue StandardError => e
      log_error "[Bot] Failed to send quick reply: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_ar_view_question
      send_quick_reply(
        title: 'AR Preview',
        request_id: 'qr_view_ar',
        message: 'Did you experience the AR preview in your environment?',
        items: [
          { title: 'Yes', identifier: '111' },
          { title: 'No', identifier: '222' }
        ]
      )
    end

    def send_ar_place_question
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

    def send_ar_file
      template = MessageTemplate.find_by(
        account_id: @conversation.account_id,
        name: 'ah_ar_guitar'
      )

      unless template
        log_error "[Bot] AR template 'ah_ar_guitar' not found - sending placeholder"
        send_text_message('[AR File: Template not found]')
        return
      end

      log_info "[Bot] 🎸 Sending AR content (Name: #{utf8_encode(template.name)}, ID: #{template.id})"

      unless template.attachments.attached?
        log_error '[Bot] AR template has no attachments - sending placeholder'
        send_text_message('[AR File: No AR file attached to template]')
        return
      end

      with_typing_indicator do
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

        message = @conversation.messages.build(params)

        template.attachments.each do |template_attachment|
          file_data = template_attachment.download
          message_attachment = message.attachments.build(
            account_id: message.account_id,
            file_type: :file
          )
          message_attachment.file.attach(
            io: StringIO.new(file_data),
            filename: template_attachment.filename.to_s,
            content_type: template_attachment.content_type
          )
          log_info "[Bot] 🎸 Attached AR file: #{utf8_encode(template_attachment.filename.to_s)}"
        end

        message.save!
        log_info "[Bot] 🎸 AR message saved with #{message.attachments.count} attachment(s)"
      end
    rescue StandardError => e
      log_error "[Bot] Failed to send AR file: #{e.message}"
      log_error e.backtrace.join("\n")
      send_text_message('[AR File: Error sending AR content]')
    end

    def send_document(filename)
      file_path = Rails.public_path.join('demo_files', 'apple_messages', filename)

      unless File.exist?(file_path)
        log_error "[Bot] Document not found: #{file_path}"
        return
      end

      log_info "[Bot] Sending document: #{utf8_encode(filename)}"

      with_typing_indicator do
        sender = message_sender
        params = bot_message_params(
          message_type: :outgoing,
          content: '',
          content_type: 'text',
          account_id: @conversation.account_id,
          inbox_id: @conversation.inbox_id,
          conversation_id: @conversation.id
        )
        params[:sender] = sender

        message = @conversation.messages.build(params)
        file_data = File.binread(file_path)

        message_attachment = message.attachments.build(
          account_id: message.account_id,
          file_type: :file
        )
        message_attachment.file.attach(
          io: StringIO.new(file_data),
          filename: filename,
          content_type: mime_type_for_filename(filename)
        )

        message.save!
        log_info "[Bot] Document message saved with #{message.attachments.count} attachment(s)"
      end
    rescue StandardError => e
      log_error "[Bot] Failed to send document: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_rich_link(url:, image_asset:, title:)
      log_info "[Bot] Sending rich link: #{utf8_encode(url)} (#{utf8_encode(title)})"

      with_typing_indicator do
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
      log_error "[Bot] Failed to send rich link: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_app_clip(url:)
      log_info "[Bot] Sending App Clip: #{utf8_encode(url)}"

      channel = @conversation.inbox.channel
      rich_link_data_ref = build_app_clip_rich_link_data_ref(channel: channel, url: url)

      with_typing_indicator do
        Messages::MessageBuilder.new(
          message_sender,
          @conversation,
          bot_message_params(
            message_type: :outgoing,
            content: url,
            content_type: 'apple_rich_link',
            content_attributes: {
              'url' => url,
              'title' => 'Open App Clip',
              'rich_link_data_ref' => rich_link_data_ref
            }
          )
        ).perform
      end
    rescue StandardError => e
      log_error "[Bot] Failed to send App Clip: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_apple_messages_rich_link
      with_typing_indicator do
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
      log_error "[Bot] Failed to send rich link: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_delivery_confirmation(address_data, customer_name = nil)
      return unless address_data.present?

      address_parts = []
      address_parts << address_data[:street] if address_data[:street].present?
      address_parts << address_data[:city]   if address_data[:city].present?
      address_parts << address_data[:state]  if address_data[:state].present?
      address_parts << address_data[:zip]    if address_data[:zip].present?
      address_parts << address_data[:country] if address_data[:country].present?

      formatted_address = address_parts.join(', ')

      message = if customer_name.present?
                  "Perfect #{customer_name}! Your order will be delivered to: #{formatted_address}"
                else
                  "Perfect! Your order will be delivered to: #{formatted_address}"
                end

      send_text_message(message)
      log_info "[Bot] 📦 Sent delivery confirmation for address: #{utf8_encode(formatted_address)}"
    end

    # === Template-based senders ===

    def send_guitar_list_picker
      template = MessageTemplate.find_by(
        account_id: @conversation.account_id,
        name: 'ah_guitar_list_picker'
      )

      unless template
        log_error "[Bot] Guitar List Picker template 'ah_guitar_list_picker' not found"
        send_text_message('Guitar selection temporarily unavailable.')
        return
      end

      log_info "[Bot] Sending Guitar List Picker (Name: #{utf8_encode(template.name)}, ID: #{template.id})"

      facade = AppleMessagesForBusiness::TemplateFacade.new(template)
      data = facade.load_data_with_images('list_picker')

      log_info "[Bot] 🎸 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"
      log_info "[Bot] 🎸 Loaded template with #{data['images']&.length || 0} images"

      sections = data['sections'] || []
      if sections.blank?
        log_error '[Bot] Guitar List Picker template has no sections'
        send_text_message('Guitar selection temporarily unavailable.')
        return
      end

      content_attrs = {
        'sections' => sections,
        'images' => data['images'] || [],
        'request_identifier' => 'lp_guitar_0319'
      }

      if data['received_title'].present?
        content_attrs['received_title']            = data['received_title']
        content_attrs['received_subtitle']         = data['received_subtitle']
        content_attrs['received_image_identifier'] = data['received_image_identifier']
        content_attrs['received_style']            = data['received_style']
      end

      if data['reply_title'].present?
        content_attrs['reply_title']            = data['reply_title']
        content_attrs['reply_subtitle']         = data['reply_subtitle']
        content_attrs['reply_image_identifier'] = data['reply_image_identifier']
        content_attrs['reply_style']            = data['reply_style']
      end

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
      log_error "[Bot] Failed to send guitar list picker: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_large_content_form
      template = MessageTemplate.find_by(
        account_id: @conversation.account_id,
        name: 'ah_large_form_demo'
      )&.reload

      unless template
        log_error "[Bot] Large Content Form template 'ah_large_form_demo' not found"
        send_text_message('Large content form is not available.')
        return
      end

      log_info "[Bot] 📋 Sending Large Content Form (Name: #{utf8_encode(template.name)}, ID: #{template.id})"

      renderer = Templates::BotRendererService.new(
        template_id: template.id,
        parameters: {},
        channel_type: 'apple_messages_for_business'
      )

      rendered = renderer.render_for_bot
      rendered[:content_type] = 'apple_form' if rendered[:content_type] != 'apple_form'
      rendered[:content_attributes]['request_identifier'] = 'form_large_content' if rendered[:content_attributes]['request_identifier'].blank?

      log_info "[Bot] 📋 Form content_type: #{rendered[:content_type]}"

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

      log_info '[Bot] 📋 Large Content Form sent successfully'
    rescue StandardError => e
      log_error "[Bot] ❌ Failed to send large content form: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_summary_list_picker
      template = MessageTemplate.find_by(
        account_id: @conversation.account_id,
        name: 'ah_summary'
      )

      unless template
        log_error "[Bot] Summary List Picker template 'ah_summary' not found"
        send_text_message('Summary temporarily unavailable.')
        return
      end

      log_info "[Bot] Sending Summary List Picker (Name: #{utf8_encode(template.name)}, ID: #{template.id})"

      facade = AppleMessagesForBusiness::TemplateFacade.new(template)
      data = facade.load_data('list_picker')

      log_info "[Bot] 📋 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"

      sections = data['sections'] || []
      if sections.blank?
        log_error '[Bot] Summary List Picker template has no sections'
        send_text_message('Summary temporarily unavailable.')
        return
      end

      content_attrs = {
        'sections' => sections,
        'request_identifier' => 'lp_summary_0319'
      }

      if data['received_title'].present?
        content_attrs['received_title']            = data['received_title']
        content_attrs['received_subtitle']         = data['received_subtitle']
        content_attrs['received_image_identifier'] = data['received_image_identifier']
        content_attrs['received_style']            = data['received_style']
      end

      if data['reply_title'].present?
        content_attrs['reply_title']            = data['reply_title']
        content_attrs['reply_subtitle']         = data['reply_subtitle']
        content_attrs['reply_image_identifier'] = data['reply_image_identifier']
        content_attrs['reply_style']            = data['reply_style']
      end

      if data['images'].is_a?(Array)
        content_attrs['images'] = data['images'].map do |image|
          { 'identifier' => image['identifier'], 'data' => image['data'], 'description' => image['description'] }.compact
        end
      end

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
      log_error "[Bot] Failed to send summary list picker: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_menu_list_picker
      log_info "[Bot] 🔍 Looking for menu template 'ah_main_menu' in account: #{@conversation.account_id}"

      template = MessageTemplate.find_by(
        account_id: @conversation.account_id,
        name: 'ah_main_menu'
      )

      unless template
        global_template = MessageTemplate.find_by(name: 'ah_main_menu')
        if global_template
          log_error "[Bot] ⚠️  Menu template 'ah_main_menu' EXISTS but in account #{global_template.account_id}, not #{@conversation.account_id}"
        else
          log_error "[Bot] ❌ Menu List Picker template 'ah_main_menu' not found in ANY account"
        end
        send_text_message('Menu temporarily unavailable.')
        return
      end

      log_info "📋 [Bot] Sending Menu List Picker (Name: #{utf8_encode(template.name)}, ID: #{template.id})"

      facade = AppleMessagesForBusiness::TemplateFacade.new(template)
      data = facade.load_data_with_images('list_picker')

      log_info "[Bot] 📋 Using #{facade.storage_type} (complexity: #{facade.complexity_score})"
      log_info "[Bot] 📋 Loaded template with #{data['images']&.length || 0} images"

      sections = data['sections'] || []
      if sections.blank?
        log_error '[Bot] ❌ Menu List Picker template has no sections'
        send_text_message('Menu temporarily unavailable.')
        return
      end

      content_attrs = {
        'sections' => sections,
        'images' => data['images'] || [],
        'request_identifier' => 'lp_menu_0319'
      }

      if data['received_title'].present?
        content_attrs['received_title']            = data['received_title']
        content_attrs['received_subtitle']         = data['received_subtitle']
        content_attrs['received_image_identifier'] = data['received_image_identifier']
        content_attrs['received_style']            = data['received_style']
      end

      if data['reply_title'].present?
        content_attrs['reply_title']            = data['reply_title']
        content_attrs['reply_subtitle']         = data['reply_subtitle']
        content_attrs['reply_image_identifier'] = data['reply_image_identifier']
        content_attrs['reply_style']            = data['reply_style']
      end

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
      log_error "[Bot] Failed to send menu list picker: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    # === Location / store / lesson senders ===

    def send_lesson_time_picker(location)
      guitar = @conversation.custom_attributes&.dig('selected_guitar') || 'guitar'

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

      time_picker_image_id = 'time_picker_lesson'

      with_typing_indicator do
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
      log_error "[Bot] Failed to send time picker: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_store_quick_reply(stores, user_coordinates)
      log_info "[Bot] 🏪 Sending #{stores.length} stores as quick reply"

      minimal_stores = stores.map do |store|
        {
          'id' => store[:id],
          'name' => store[:name],
          'latitude' => store[:latitude],
          'longitude' => store[:longitude],
          'distance_km' => store[:distance_km]
        }
      end

      set_conv_attr('available_stores', minimal_stores.to_json)
      set_conv_attr('store_search_lat', user_coordinates[:latitude])
      set_conv_attr('store_search_lon', user_coordinates[:longitude])

      items = stores.map.with_index { |store, index| { title: store[:name], value: index.to_s } }

      send_quick_reply(
        title: "Select your nearest Apple Store (#{stores.length} found)",
        request_id: 'qr_store_selection',
        items: items
      )
    rescue StandardError => e
      log_error "[Bot] Failed to send store quick reply: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    def send_store_selection_list_picker(stores, user_coordinates)
      return if stores.blank?

      apple_store_image_id = 'apple_store_logo'

      items = stores.map.with_index do |store, index|
        {
          'identifier' => index.to_s,
          'title' => store[:name],
          'subtitle' => "#{store[:distance_km]} km away • #{store[:formatted_address]}",
          'style' => 'large',
          'image_identifier' => apple_store_image_id
        }
      end

      sections = [{ 'title' => 'Nearby Apple Stores', 'multiple_selection' => false, 'items' => items }]

      set_conv_attr('store_search_lat', user_coordinates[:latitude])
      set_conv_attr('store_search_lon', user_coordinates[:longitude])

      minimal_stores = stores.map do |store|
        {
          'id' => store[:id],
          'name' => store[:name],
          'latitude' => store[:latitude],
          'longitude' => store[:longitude],
          'distance_km' => store[:distance_km]
        }
      end
      set_conv_attr('available_stores', minimal_stores.to_json)

      images = fetch_and_encode_images([apple_store_image_id])
      log_info "[Bot] 🏪 Encoded #{images.length} images for store selection list picker"

      with_typing_indicator do
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
              'reply_subtitle' => "Let's schedule your lesson",
              'reply_image_identifier' => apple_store_image_id
            }
          )
        ).perform
      end
    rescue StandardError => e
      log_error "[Bot] Failed to send store selection list picker: #{e.message}"
      log_error e.backtrace.join("\n")
    end

    # === Apple Pay ===

    def send_apple_pay_request(guitar_name)
      with_typing_indicator do
        image_identifier = get_guitar_image_identifier(guitar_name)
        log_info "[Bot] 💳 Apple Pay request for '#{utf8_encode(guitar_name)}' with image: #{image_identifier}"

        payment_data = {
          'request_identifier' => 'applepay_1018',
          'merchant_name' => 'Acoustic House',
          'currency_code' => 'USD',
          'country_code' => 'US',
          'line_items' => [{ 'label' => guitar_name, 'amount' => '0.01', 'type' => 'final' }],
          'total' => { 'label' => 'Acoustic House', 'amount' => '0.01', 'type' => 'final' },
          'received_title' => "Buy your new #{guitar_name}",
          'received_subtitle' => 'test payment',
          'received_style' => 'large',
          'received_image_identifier' => image_identifier,
          'reply_style' => 'large',
          'reply_image_identifier' => image_identifier
        }

        service = AppleMessagesForBusiness::SendApplePayService.new(
          channel: @conversation.inbox.channel,
          destination_id: @conversation.contact_inbox.source_id,
          payment_data: payment_data
        )

        log_info '[Bot] 💳 Calling SendApplePayService.perform...'
        response = service.perform
        log_info "[Bot] 💳 SendApplePayService returned: #{response.inspect}"

        if response[:success]
          stored_payment_data = payment_data.except('request_identifier', 'reply_image_identifier')

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

          message = @conversation.messages.create(message_params)
          if message.persisted?
            log_info '[Bot] ✅ Apple Pay message created successfully'
          else
            log_warn "[Bot] ⚠️ Apple Pay message creation failed: #{message.errors.full_messages.join(', ')}"
          end

          { success: true }
        else
          log_info "[Bot] ❌ Apple Pay failed: #{utf8_encode(response[:error])}"
          response
        end
      end
    rescue StandardError => e
      log_error "[Bot] 💳 Exception in send_apple_pay_request: #{e.message}"
      log_error e.backtrace.join("\n")
      { success: false, error: e.message }
    end

    # === OAuth ===

    def send_oauth_authentication(provider)
      log_info "[Bot] 🔐 Sending OAuth authentication for provider: #{provider}"

      message_content = case provider.downcase
                        when 'linkedin' then 'Sign in with LinkedIn to access your professional profile'
                        when 'google'   then 'Sign in with Google to continue'
                        when 'facebook' then 'Sign in with Facebook to continue'
                        else "Sign in with #{provider.capitalize} to continue"
                        end

      service = AppleMessagesForBusiness::SendAuthenticationService.new(
        channel: @conversation.inbox.channel,
        destination_id: @conversation.contact_inbox.source_id,
        authentication_data: { 'provider' => provider },
        message_content: message_content
      )

      result = service.perform

      if result[:success]
        log_info '[Bot] ✅ OAuth authentication message sent successfully'
      else
        log_warn "[Bot] ❌ OAuth authentication failed: #{result[:error] || 'unknown error'}"
        send_text_message('Sorry, there was an error sending the authentication request. Please try again.')
      end
    rescue StandardError => e
      log_error "[Bot] ❌ Exception in send_oauth_authentication: #{e.message}"
      log_error e.backtrace.join("\n")
      send_text_message('Sorry, there was an error sending the authentication request. Please try again.')
    end

    # === Image helpers ===

    def fetch_and_encode_images(identifiers)
      return [] if identifiers.empty?

      images = AppleMessagesForBusiness::ImageFetchService.new(
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
        embedded_images: []
      ).fetch_and_encode(identifiers)

      log_info "[Bot] 🖼️ Looking for images with identifiers: #{identifiers.inspect}"
      log_info "[Bot] 🖼️ Found #{images.count}/#{identifiers.count} images"

      images.map do |image|
        { 'identifier' => image[:identifier], 'data' => image[:data], 'description' => image[:description] || '' }
      end
    end

    private

    # === Typing indicators ===

    def with_typing_indicator
      return yield unless typing_indicators_enabled?

      send_typing_indicator(:start)
      sleep(typing_indicator_delay)
      result = yield
      send_typing_indicator(:end)
      result
    rescue StandardError => e
      send_typing_indicator(:end)
      raise e
    end

    def send_typing_indicator(action)
      return unless typing_indicators_enabled?
      return unless apple_messages_channel?

      apple_source_urn = @conversation.contact&.additional_attributes&.dig('apple_messages_source_id')
      return unless apple_source_urn

      destination_id = apple_source_urn.sub(/^urn:biz:/, '')

      service = AppleMessagesForBusiness::OutgoingTypingIndicatorService.new(
        channel: @conversation.inbox.channel,
        destination_id: destination_id,
        action: action
      )

      result = service.perform
      log_info "[Bot] Typing indicator #{action}: #{result[:success] ? 'success' : utf8_encode(result[:error])}"
    rescue StandardError => e
      Rails.logger.error utf8_encode("[Bot] Failed to send typing indicator: #{e.message}")
    end

    def apple_messages_channel?
      @conversation.inbox.channel.is_a?(Channel::AppleMessagesForBusiness)
    end

    # === Message building ===

    def bot_message_params(base_params)
      agent_bot = bot_user
      return base_params unless agent_bot.present?

      base_params.merge(sender_type: 'AgentBot', sender_id: agent_bot.id)
    end

    def message_sender
      bot_user.presence || @conversation.account.users.first
    end

    def bot_user
      @conversation.inbox.agent_bot
    end

    # === Misc helpers ===

    def image_url_for_asset(image_asset)
      return nil if image_asset.blank?
      return image_asset if image_asset.start_with?('http://', 'https://')

      base_url = ENV.fetch('FRONTEND_URL', nil) ||
                 @conversation.inbox&.channel&.webhook_url&.match(%r{^https?://[^/]+})&.to_s

      base_url.present? ? "#{base_url}/demo_files/apple_messages/#{image_asset}" : nil
    end

    def mime_type_for_filename(filename)
      case File.extname(filename).downcase
      when '.pdf'     then 'application/pdf'
      when '.numbers' then 'application/vnd.apple.numbers'
      when '.pages'   then 'application/vnd.apple.pages'
      when '.key'     then 'application/vnd.apple.keynote'
      else 'application/octet-stream'
      end
    end

    def build_app_clip_rich_link_data_ref(channel:, url:)
      return { 'url' => url } unless channel

      construct_result = AppleMessagesForBusiness::ConstructPayloadService.new(
        channel: channel,
        url: url
      ).perform

      if construct_result[:success] && construct_result[:rich_link_data_ref].present?
        construct_result[:rich_link_data_ref]
      else
        log_warn "[Bot] App Clip constructPayload failed: #{construct_result[:error] || 'unknown error'}"
        { 'url' => url }
      end
    rescue StandardError => e
      log_warn "[Bot] App Clip constructPayload exception: #{e.message}"
      { 'url' => url }
    end

    # rubocop:disable Metrics/MethodLength
    def get_guitar_image_identifier(guitar_name)
      return nil if guitar_name.blank?

      fallback_identifier = 'guitar_lespaul'

      guitar_image_map = {
        'Fender American Elite Stratocaster' => 'guitar_stratocaster',
        'Gibson ES-335' => 'guitar_gibson_es335',
        'Martin DC28E Dreadnought' => 'guitar_martin_dreadnought',
        'Gibson Les Paul Standard' => 'guitar_lespaul',
        'PRS Custom 24' => 'guitar_prs_custom24',
        'Taylor 814ce' => 'guitar_taylor',
        'Stratocaster' => 'guitar_stratocaster',
        'Les Paul' => 'guitar_lespaul',
        'Martin' => 'guitar_martin_dreadnought',
        'Dreadnought' => 'guitar_martin_dreadnought',
        'Gibson' => 'guitar_lespaul',
        'Fender' => 'guitar_stratocaster',
        'PRS' => 'guitar_prs_custom24',
        'Taylor' => 'guitar_taylor',
        'Demo Guitar - Fender Stratocaster' => 'guitar_stratocaster'
      }

      return guitar_image_map[guitar_name] if guitar_image_map.key?(guitar_name)

      match = guitar_image_map.find { |key, _| guitar_name.include?(key) }
      return match[1] if match

      Rails.logger.info "[Bot] 🎸 No image found for guitar '#{guitar_name}', using fallback: #{fallback_identifier}"
      fallback_identifier
    end
    # rubocop:enable Metrics/MethodLength

    # Directly write a conversation attribute (bypasses state_manager for simple writes).
    def set_conv_attr(key, value)
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes[key] = value
      @conversation.save!
    end
  end
end
