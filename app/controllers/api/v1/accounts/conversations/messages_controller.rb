class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :normalize_apple_messages_content_attributes, only: :create
  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource

    # Use Apple Messages processor for automatic URL-to-Rich Link conversion
    if @conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'
      processor = AppleMessagesForBusiness::MessageProcessorService.new(@conversation, create_params, user)
      @message = processor.process_and_send

      # Handle multiple messages case
      if @message.is_a?(Array)
        @message = @message.last # Return the last message for response
      end

      # Trigger bot if enabled and message is incoming
      trigger_apple_messages_bot(@message) if @message.incoming?
    else
      # Regular message creation for non-Apple Messages conversations
      mb = Messages::MessageBuilder.new(user, @conversation, create_params)
      @message = mb.perform
    end
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  def send_apple_pay
    # Validate that this is an Apple Messages for Business conversation
    unless @conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'
      return render json: { error: 'Apple Pay is only available for Apple Messages for Business' }, status: :unprocessable_entity
    end

    # Get channel and destination_id
    channel = @conversation.inbox.channel
    contact_inbox = @conversation.contact_inbox
    destination_id = contact_inbox.source_id

    # Validate required parameters
    validation_result = validate_apple_pay_params
    return render json: validation_result, status: :unprocessable_entity if validation_result[:errors]

    # Normalize payment data from camelCase to snake_case
    payment_data = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
      apple_pay_params.to_unsafe_h
    )

    # Send Apple Pay request
    service = AppleMessagesForBusiness::SendApplePayService.new(
      channel: channel,
      destination_id: destination_id,
      payment_data: payment_data
    )

    result = service.perform

    if result[:success]
      render json: {
        success: true,
        message_id: result[:message_id],
        message: 'Apple Pay request sent successfully'
      }, status: :ok
    else
      render json: {
        success: false,
        error: result[:error] || 'Failed to send Apple Pay request'
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[MessagesController] Apple Pay send failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: "Failed to send Apple Pay request: #{e.message}" }, status: :internal_server_error
  end

  private

  def trigger_apple_messages_bot(message)
    return unless bot_enabled?
    return unless message.incoming?

    # Don't trigger bot for blocked contacts (users who closed the conversation)
    if contact_blocked_from_apple_messages?
      Rails.logger.info '[Apple Messages Bot] Skipping bot - contact is blocked (opted out)'
      return
    end

    bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
      @conversation,
      message
    )

    # Check if this is an interactive response (quick reply, list picker, time picker, etc.)
    if params[:interactive_data].present?
      bot_service.process_interactive_response(params[:interactive_data].to_unsafe_h)
    else
      bot_service.process_message
    end
  rescue StandardError => e
    Rails.logger.error "[Apple Messages Bot] Error processing message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def bot_enabled?
    # Check if bot is enabled in conversation custom_attributes
    # Default to true if not set (opt-out model)
    attrs = @conversation.custom_attributes || {}
    attrs.fetch('bot_enabled', true)
  end

  def contact_blocked_from_apple_messages?
    # Check if contact has been blocked due to closing the conversation on their device
    return false unless @conversation.inbox.channel_type == 'Channel::AppleMessagesForBusiness'

    @conversation.contact.additional_attributes&.dig('apple_messages_blocked') == true
  end

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error)
  end

  def create_params
    if params[:content_type]&.start_with?('apple_')
      image_count = params.dig(:content_attributes, :images)&.length || 0
      Rails.logger.debug { "🔥 MessagesController create_params - Type: #{params[:content_type]}, Images: #{image_count}" }
    end

    permitted = params.permit(:content, :private, :message_type, :content_type, :echo_id, :sender_type, :sender_id, :external_created_at, :template_id,
                              :attachments => [],
                              # Apple Messages interactive response data
                              :interactive_data => [:requestIdentifier, { :data => {} }],
                              :content_attributes => [
                                # Common type field for all Apple Messages
                                :type,
                                # Apple Quick Reply
                                :summary_text, { :items => [:title, :identifier, :description] },
                                { :replies => [:title, :identifier, :description, :imageIdentifier, :image_identifier] },
                                # Apple List Picker
                                { :sections => [:title, :multiple_selection, { :items => [:title, :subtitle, :identifier, :imageIdentifier, :image_identifier] }] },
                                { :images => [:identifier, :data, :description] },  # Fixed: Allow nested image structure
                                # Apple Time Picker
                                { :event => [:title, :description, :identifier, { :timeslots => [:identifier, :start_time, :duration] }] },
                                :timezone_offset,
                                # Apple Rich Link
                                :url, :title, :description, :image_url, :site_name,
                                # Apple Form
                                :title, :description, :submit_url, :method, :validation_rules,
                                :version, :form_id, :use_live_layout,
                                { :submit_button => [:title] },
                                { :cancel_button => [:title] },
                                { :fields => [:type, :name, :label, :placeholder, :required, :default, :pattern, :title, :pattern_error, { :options => [:value, :title, :description] }] },
                                { :pages => [:page_id, :title, :description, { :items => [
                                  # Base fields
                                  :item_id, :item_type, :title, :description, :required, :placeholder, :default_value,
                                  # Text/TextArea/Email/Phone fields
                                  :max_length, :keyboard_type, :text_content_type,
                                  # Select fields (singleSelect/multiSelect)
                                  { :options => [:id, :value, :title, :description, :image_identifier, :imageIdentifier] },
                                  # DateTime fields
                                  :date_format, :min_date, :max_date,
                                  # Toggle fields
                                  :toggle_style,
                                  # Stepper fields
                                  :min_value, :max_value, :step,
                                  # Picker fields
                                  :picker_type, :picker_options,
                                  # RichLink fields
                                  :url, :image_url,
                                  # Button fields
                                  :button_style, :action
                                ] }] },
                                # Apple Custom App
                                :app_id, :app_name, :bid, :url, :use_live_layout,
                                # Common Apple Messages fields (flat structure for backward compatibility)
                                :received_title, :received_subtitle, :received_image_identifier, :received_style,
                                :reply_title, :reply_subtitle, :reply_style,
                                :reply_image_title, :reply_image_subtitle,
                                :reply_secondary_subtitle, :reply_tertiary_subtitle,
                                :reply_image_identifier,
                                # Nested message structures (new form builder format)
                                { :received_message => [:title, :subtitle, :image_identifier, :imageIdentifier, :style] },
                                { :reply_message => [:title, :subtitle, :image_identifier, :imageIdentifier, :style] },
                                # Apple Pay
                                :merchant_name, :merchantName, :currency_code, :currencyCode, :country_code, :countryCode,
                                :requires_shipping, :requiresShipping, :requires_billing, :requiresBilling,
                                { :line_items => [:label, :amount, :type] },
                                { :lineItems => [:label, :amount, :type] },
                                { :total => [:label, :amount, :type] },
                                { :shipping_methods => [:identifier, :label, :detail, :amount] },
                                { :shippingMethods => [:identifier, :label, :detail, :amount] },
                                :required_billing_fields, :requiredBillingFields,
                                :required_shipping_fields, :requiredShippingFields
                              ])

    if permitted[:content_type]&.start_with?('apple_')
      image_count = permitted.dig(:content_attributes, :images)&.length || 0
      Rails.logger.debug { "🔥 MessagesController permitted - Type: #{permitted[:content_type]}, Images: #{image_count}" }
    end

    permitted
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # Normalize Apple Messages content_attributes from camelCase to snake_case
  # This ensures consistent internal storage format regardless of frontend input
  def normalize_apple_messages_content_attributes
    return if params[:content_attributes].blank?
    return unless apple_messages_content_type?

    Rails.logger.info '[API] Normalizing Apple Messages content_attributes from camelCase to snake_case'

    # Log structure only, not the actual data
    before_keys = params[:content_attributes].keys
    Rails.logger.info "[API] Before normalization - Keys: #{before_keys.join(', ')}"

    # Convert from frontend camelCase to internal snake_case
    params[:content_attributes] = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
      params[:content_attributes].to_unsafe_h
    )

    # Log structure only, not the actual data
    after_keys = params[:content_attributes].keys
    Rails.logger.info "[API] After normalization - Keys: #{after_keys.join(', ')}"
  end

  def apple_messages_content_type?
    content_type = params[:content_type]
    content_type&.start_with?('apple_')
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end

  # Validate Apple Pay parameters
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def validate_apple_pay_params
    errors = []

    # Required fields
    errors << 'merchant_name is required' if params[:merchant_name].blank?
    errors << 'currency_code is required' unless params[:currency_code].present? || params[:currencyCode].present?
    errors << 'country_code is required' unless params[:country_code].present? || params[:countryCode].present?

    # Line items validation
    line_items = params[:line_items] || params[:lineItems] || []
    if line_items.empty?
      errors << 'At least one line item is required'
    else
      line_items.each_with_index do |item, index|
        errors << "Line item #{index + 1}: label is required" if item[:label].blank?
        errors << "Line item #{index + 1}: amount is required" if item[:amount].blank?
      end
    end

    # Total validation
    total = params[:total]
    if total.blank?
      errors << 'total is required'
    else
      errors << 'total.label is required' if total[:label].blank?
      errors << 'total.amount is required' if total[:amount].blank?
    end

    return { errors: errors } if errors.any?

    nil
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  # Strong parameters for Apple Pay request
  def apple_pay_params
    params.permit(
      :merchant_name, :merchantName,
      :merchant_identifier, :merchantIdentifier,
      :currency_code, :currencyCode,
      :country_code, :countryCode,
      :received_title, :receivedTitle,
      :received_subtitle, :receivedSubtitle,
      :received_style, :receivedStyle,
      :received_image_identifier, :receivedImageIdentifier,
      line_items: [:label, :amount, :type],
      lineItems: [:label, :amount, :type],
      total: [:label, :amount, :type],
      supported_networks: [],
      supportedNetworks: [],
      merchant_capabilities: [],
      merchantCapabilities: [],
      required_billing_contact_fields: [],
      requiredBillingContactFields: [],
      required_shipping_contact_fields: [],
      requiredShippingContactFields: [],
      shipping_methods: [:identifier, :label, :detail, :amount],
      shippingMethods: [:identifier, :label, :detail, :amount],
      images: [:identifier, :data, :description]
    )
  end
end
