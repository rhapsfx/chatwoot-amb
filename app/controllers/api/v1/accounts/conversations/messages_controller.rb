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

  private

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
    Rails.logger.info "🔥 MessagesController create_params called with: #{params.inspect}"
    Rails.logger.info "🔥 MessagesController content_attributes: #{params[:content_attributes]}"
    Rails.logger.info "🔥 MessagesController images in content_attributes: #{params.dig(:content_attributes, :images)}"

    permitted = params.permit(:content, :private, :message_type, :content_type, :echo_id, :sender_type, :sender_id, :external_created_at,
                              :attachments => [],
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
                                  { :options => [:value, :title, :description] },
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
                                { :reply_message => [:title, :subtitle, :image_identifier, :imageIdentifier, :style] }
                              ])

    Rails.logger.info "🔥 MessagesController permitted params: #{permitted.inspect}"
    Rails.logger.info "🔥 MessagesController permitted content_attributes: #{permitted[:content_attributes]}"
    Rails.logger.info "🔥 MessagesController permitted images: #{permitted.dig(:content_attributes, :images)}"

    permitted
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # Normalize Apple Messages content_attributes from camelCase to snake_case
  # This ensures consistent internal storage format regardless of frontend input
  def normalize_apple_messages_content_attributes
    return unless params[:content_attributes].present?
    return unless apple_messages_content_type?

    Rails.logger.info '[API] Normalizing Apple Messages content_attributes from camelCase to snake_case'
    Rails.logger.info "[API] Before normalization: #{params[:content_attributes].inspect}"

    # Convert from frontend camelCase to internal snake_case
    params[:content_attributes] = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
      params[:content_attributes].to_unsafe_h
    )

    Rails.logger.info "[API] After normalization: #{params[:content_attributes].inspect}"
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
end
