# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# TemplateExecutorService - Executes BotActionTemplate instances by routing to appropriate AMB services
#
# This service is the heart of the template-based action system. It takes a BotActionTemplate
# instance and executes it by calling the appropriate Apple Messages for Business services.
#
# Usage:
#   service = AppleMessagesForBusiness::TemplateExecutorService.new(
#     template: bot_action_template,
#     conversation: conversation,
#     message: message
#   )
#   messages_sent = service.execute
#   # Returns: Integer (number of messages sent)
#
# Supported Template Types:
#   - send_text_message: Plain text messages
#   - send_list_picker: Interactive list picker from MessageTemplate
#   - send_time_picker: Time picker from MessageTemplate
#   - send_form: Apple Messages form from MessageTemplate
#   - send_rich_link: Rich link with image and metadata
#   - send_quick_reply: Quick reply with predefined options
#   - update_attributes: Update conversation custom attributes
#   - conditional_branch: Execute actions based on conditions
#   - send_apple_pay: Apple Pay payment request
#   - api_call: External API integration
#   - send_imessage_app: Custom iMessage app invocation
#   - send_app_clip: App Clip invocation
#
class AppleMessagesForBusiness::TemplateExecutorService
  def initialize(template:, conversation:, message:)
    @template = template
    @conversation = conversation
    @message = message
    @account = @template.account
    @inbox = @conversation.inbox
    @channel = @inbox.channel
  end

  # Execute the template and return the number of messages sent
  # Returns: Integer (0 if no messages sent, 1+ if messages sent)
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def execute
    log_info "[TemplateExecutor] Starting execution - Template: #{@template.name} (#{@template.template_type})"

    # Validate that we have required context
    unless valid_context?
      log_error '[TemplateExecutor] Invalid context - missing required objects'
      return 0
    end

    # Route to appropriate executor method
    messages_sent = case @template.template_type
                    when 'send_text_message'
                      execute_send_text_message
                    when 'send_list_picker'
                      execute_send_list_picker
                    when 'send_time_picker'
                      execute_send_time_picker
                    when 'send_form'
                      execute_send_form
                    when 'send_rich_link'
                      execute_send_rich_link
                    when 'send_quick_reply'
                      execute_send_quick_reply
                    when 'update_attributes'
                      execute_update_attributes
                    when 'conditional_branch'
                      execute_conditional_branch
                    when 'send_apple_pay'
                      execute_send_apple_pay
                    when 'api_call'
                      execute_api_call
                    when 'send_imessage_app'
                      execute_send_imessage_app
                    when 'send_app_clip'
                      execute_send_app_clip
                    else
                      log_error "[TemplateExecutor] Unknown template type: #{@template.template_type}"
                      0
                    end

    log_info "[TemplateExecutor] Execution complete - Messages sent: #{messages_sent}"
    messages_sent
  rescue StandardError => e
    log_error "[TemplateExecutor] Execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    0
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # Validate that we have all required context objects
  def valid_context?
    @template.present? && @conversation.present? && @account.present?
  end

  # A. send_text_message
  def execute_send_text_message
    params = @template.parameters
    content = params['message']

    if content.blank?
      log_error '[TemplateExecutor] send_text_message: Missing message content'
      return 0
    end

    # Apply delay if specified
    delay_seconds = params['delay_seconds'].to_i
    sleep(delay_seconds) if delay_seconds.positive?

    # Create outgoing message in Chatwoot
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: content,
      content_type: 'text',
      sender: @account.administrators.first # Bot sends as first admin
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendMessageService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      # Update message status to 'sent' and set sent_at timestamp
      outgoing_message.update!(status: :sent, sent_at: Time.current)
      log_info "[TemplateExecutor] send_text_message: Successfully sent - #{content[0..50]}"
      1
    else
      # Update message status to 'failed'
      outgoing_message.update!(status: :failed)
      log_error "[TemplateExecutor] send_text_message: Failed - #{result[:error]}"
      0
    end
  end

  # B. send_list_picker
  def execute_send_list_picker
    params = @template.parameters
    template_id = params['template_id']

    message_template = MessageTemplate.find_by(id: template_id, account: @account)
    unless message_template
      log_error "[TemplateExecutor] send_list_picker: Template not found - ID: #{template_id}"
      return 0
    end

    # Load template data with images using TemplateFacade
    facade = AppleMessagesForBusiness::TemplateFacade.new(message_template)
    list_picker_data = facade.load_data_with_images('list_picker')

    if list_picker_data.blank?
      log_error "[TemplateExecutor] send_list_picker: No list picker data in template #{template_id}"
      return 0
    end

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: list_picker_data['received_title'] || 'Select an option',
      content_type: 'apple_list_picker',
      content_attributes: list_picker_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendListPickerService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_list_picker: Successfully sent - Template: #{message_template.name}"
      1
    else
      log_error "[TemplateExecutor] send_list_picker: Failed - #{result[:error]}"
      0
    end
  end

  # C. send_time_picker
  def execute_send_time_picker
    params = @template.parameters
    template_id = params['template_id']

    message_template = MessageTemplate.find_by(id: template_id, account: @account)
    unless message_template
      log_error "[TemplateExecutor] send_time_picker: Template not found - ID: #{template_id}"
      return 0
    end

    # Load template data using TemplateFacade
    # Note: Time picker uses individual image identifier fields (received_image_identifier, reply_image_identifier)
    # NOT an images array like list_picker/form, so we use load_data instead of load_data_with_images
    facade = AppleMessagesForBusiness::TemplateFacade.new(message_template)
    time_picker_data = facade.load_data('time_picker')

    if time_picker_data.blank?
      log_error "[TemplateExecutor] send_time_picker: No time picker data in template #{template_id}"
      return 0
    end

    # Merge in optional parameters
    # Note: Only timezone_offset is allowed; location_data is NOT in ALLOWED_APPLE_TIME_PICKER_KEYS
    time_picker_data['timezone_offset'] = params['timezone_offset'] if params['timezone_offset']

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: time_picker_data['received_title'] || 'Select a time',
      content_type: 'apple_time_picker',
      content_attributes: time_picker_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendMessageService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_time_picker: Successfully sent - Template: #{message_template.name}"
      1
    else
      log_error "[TemplateExecutor] send_time_picker: Failed - #{result[:error]}"
      0
    end
  end

  # D. send_form
  def execute_send_form
    params = @template.parameters
    template_id = params['template_id']

    message_template = MessageTemplate.find_by(id: template_id, account: @account)
    unless message_template
      log_error "[TemplateExecutor] send_form: Template not found - ID: #{template_id}"
      return 0
    end

    # Load template data with images using TemplateFacade
    facade = AppleMessagesForBusiness::TemplateFacade.new(message_template)
    form_data = facade.load_data_with_images('form')

    if form_data.blank?
      log_error "[TemplateExecutor] send_form: No form data in template #{template_id}"
      return 0
    end

    # Merge in pre-fill data if provided
    form_data['pre_fill_data'] = params['pre_fill_data'] if params['pre_fill_data'].present?

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: form_data['title'] || 'Please fill out this form',
      content_type: 'apple_form',
      content_attributes: form_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendMessageService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_form: Successfully sent - Template: #{message_template.name}"
      1
    else
      log_error "[TemplateExecutor] send_form: Failed - #{result[:error]}"
      0
    end
  end

  # E. send_rich_link
  def execute_send_rich_link
    params = @template.parameters

    unless params['url'].present? && params['title'].present?
      log_error '[TemplateExecutor] send_rich_link: Missing required url or title'
      return 0
    end

    # Build rich link content attributes
    rich_link_data = {
      'url' => params['url'],
      'title' => params['title'],
      'subtitle' => params['subtitle'],
      'image_url' => params['image_url']
    }.compact

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: params['title'],
      content_type: 'apple_rich_link',
      content_attributes: rich_link_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendRichLinkService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_rich_link: Successfully sent - #{params['url']}"
      1
    else
      log_error "[TemplateExecutor] send_rich_link: Failed - #{result[:error]}"
      0
    end
  end

  # F. send_quick_reply
  def execute_send_quick_reply
    params = @template.parameters

    unless params['message'].present? && params['items'].present?
      log_error '[TemplateExecutor] send_quick_reply: Missing required message or items'
      return 0
    end

    # Build quick reply content attributes using CaseTransformer
    quick_reply_data = {
      'source_id' => params['request_id'] || SecureRandom.uuid,
      'items' => params['items']
    }

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: params['message'],
      content_type: 'apple_quick_reply',
      content_attributes: quick_reply_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendQuickReplyService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_quick_reply: Successfully sent - #{params['items'].length} options"
      1
    else
      log_error "[TemplateExecutor] send_quick_reply: Failed - #{result[:error]}"
      0
    end
  end

  # G. update_attributes
  def execute_update_attributes
    params = @template.parameters
    attributes = params['attributes']

    unless attributes.is_a?(Hash) && attributes.present?
      log_error '[TemplateExecutor] update_attributes: Missing or invalid attributes'
      return 0
    end

    # Merge new attributes with existing
    current_attrs = @conversation.custom_attributes || {}
    updated_attrs = current_attrs.merge(attributes)

    @conversation.update!(custom_attributes: updated_attrs)

    log_info "[TemplateExecutor] update_attributes: Updated #{attributes.keys.join(', ')}"
    0 # No messages sent
  end

  # H. conditional_branch
  def execute_conditional_branch
    params = @template.parameters

    # Evaluate condition
    condition_met = evaluate_condition(
      params['condition_type'],
      params['condition_value']
    )

    log_info "[TemplateExecutor] conditional_branch: Condition evaluated to #{condition_met}"

    # Execute appropriate action template
    action_template_id = condition_met ? params['true_action'] : params['false_action']

    if action_template_id.blank?
      log_info '[TemplateExecutor] conditional_branch: No action specified for branch'
      return 0
    end

    action_template = BotActionTemplate.find_by(id: action_template_id, account: @account)
    unless action_template
      log_error "[TemplateExecutor] conditional_branch: Action template not found - ID: #{action_template_id}"
      return 0
    end

    # Recursively execute the action template
    log_info "[TemplateExecutor] conditional_branch: Executing action template: #{action_template.name}"
    self.class.new(
      template: action_template,
      conversation: @conversation,
      message: @message
    ).execute
  end

  # I. send_apple_pay
  def execute_send_apple_pay
    params = @template.parameters

    # Validate required parameters
    required_params = %w[merchant_id item_name amount]
    missing = required_params.select { |p| params[p].blank? }
    if missing.any?
      log_error "[TemplateExecutor] send_apple_pay: Missing required parameters: #{missing.join(', ')}"
      return 0
    end

    # Build Apple Pay payment data using CaseTransformer
    payment_data = {
      'merchant_name' => params['merchant_name'] || @account.name,
      'merchant_id' => params['merchant_id'],
      'currency' => params['currency'] || 'USD',
      'country_code' => params['country_code'] || 'US',
      'line_items' => [
        {
          'label' => params['item_name'],
          'amount' => params['amount']
        }
      ],
      'total' => {
        'label' => 'Total',
        'amount' => params['amount']
      }
    }

    # Get destination_id
    dest_id = destination_id
    return 0 unless dest_id

    # Send via ApplePayService
    result = AppleMessagesForBusiness::SendApplePayService.new(
      channel: @channel,
      destination_id: dest_id,
      payment_data: payment_data
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_apple_pay: Successfully sent - #{params['item_name']} - $#{params['amount']}"
      1
    else
      log_error "[TemplateExecutor] send_apple_pay: Failed - #{result[:error]}"
      0
    end
  end

  # J. api_call
  def execute_api_call
    params = @template.parameters

    unless params['url'].present? && params['method'].present?
      log_error '[TemplateExecutor] api_call: Missing required url or method'
      return 0
    end

    # Make HTTP request
    response = make_http_request(
      url: params['url'],
      method: params['method'].upcase,
      headers: params['headers'] || {},
      body: params['body']
    )

    # Store response if requested
    if params['store_response_in'].present?
      current_attrs = @conversation.custom_attributes || {}
      current_attrs[params['store_response_in']] = response
      @conversation.update!(custom_attributes: current_attrs)
      log_info "[TemplateExecutor] api_call: Stored response in '#{params['store_response_in']}'"
    end

    log_info "[TemplateExecutor] api_call: Completed #{params['method']} to #{params['url']}"
    0 # API call doesn't send messages
  rescue StandardError => e
    log_error "[TemplateExecutor] api_call: Failed - #{e.message}"
    0
  end

  # K. send_imessage_app
  def execute_send_imessage_app
    params = @template.parameters

    unless params['app_id'].present? && params['app_name'].present?
      log_error '[TemplateExecutor] send_imessage_app: Missing required app_id or app_name'
      return 0
    end

    # Build iMessage app data using CaseTransformer
    imessage_app_data = {
      'app_id' => params['app_id'],
      'app_name' => params['app_name'],
      'app_icon_url' => params['app_icon_url'],
      'launch_url' => params['launch_url'],
      'data' => params['data'],
      'bid' => params['bid'],
      'received_title' => params['app_name'],
      'received_subtitle' => params['subtitle'] || 'Tap to view'
    }.compact

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: params['app_name'],
      content_type: 'apple_custom_app',
      content_attributes: imessage_app_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendMessageService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_imessage_app: Successfully sent - #{params['app_name']}"
      1
    else
      log_error "[TemplateExecutor] send_imessage_app: Failed - #{result[:error]}"
      0
    end
  end

  # L. send_app_clip
  def execute_send_app_clip
    params = @template.parameters

    unless params['app_clip_url'].present? && params['title'].present?
      log_error '[TemplateExecutor] send_app_clip: Missing required app_clip_url or title'
      return 0
    end

    # Build App Clip data using CaseTransformer (uses rich link format)
    app_clip_data = {
      'url' => params['app_clip_url'],
      'title' => params['title'],
      'subtitle' => params['subtitle'],
      'image_url' => params['image_url'],
      'action_title' => params['action_title'] || 'Open'
    }.compact

    # Create outgoing message
    outgoing_message = @conversation.messages.create!(
      account_id: @account.id,
      inbox_id: @inbox.id,
      message_type: :outgoing,
      content: params['title'],
      content_type: 'apple_rich_link',
      content_attributes: app_clip_data,
      sender: @account.administrators.first
    )

    # Send via Apple Messages
    dest_id = destination_id
    return 0 unless dest_id

    result = AppleMessagesForBusiness::SendRichLinkService.new(
      channel: @channel,
      destination_id: dest_id,
      message: outgoing_message
    ).perform

    if result[:success]
      log_info "[TemplateExecutor] send_app_clip: Successfully sent - #{params['title']}"
      1
    else
      log_error "[TemplateExecutor] send_app_clip: Failed - #{result[:error]}"
      0
    end
  end

  # Evaluate condition for conditional_branch
  def evaluate_condition(condition_type, condition_value)
    case condition_type
    when 'attribute_equals'
      attr_name = condition_value['attribute']
      expected_value = condition_value['value']
      actual_value = @conversation.custom_attributes&.dig(attr_name)
      actual_value == expected_value
    when 'attribute_contains'
      attr_name = condition_value['attribute']
      search_value = condition_value['value']
      actual_value = @conversation.custom_attributes&.dig(attr_name)
      actual_value&.to_s&.include?(search_value.to_s)
    when 'message_contains'
      search_text = condition_value['text']
      @message.content&.downcase&.include?(search_text.downcase)
    when 'message_matches_regex'
      pattern = Regexp.new(condition_value['pattern'], Regexp::IGNORECASE)
      pattern.match?(@message.content || '')
    when 'attribute_exists'
      attr_name = condition_value['attribute']
      @conversation.custom_attributes&.key?(attr_name)
    when 'attribute_greater_than'
      attr_name = condition_value['attribute']
      threshold = condition_value['value'].to_f
      actual_value = @conversation.custom_attributes&.dig(attr_name).to_f
      actual_value > threshold
    when 'custom_expression'
      # WARNING: Eval is dangerous - use with caution in production
      # Only use in controlled environments with trusted templates
      eval(condition_value['expression']) # rubocop:disable Security/Eval
    else
      log_warn "[TemplateExecutor] Unknown condition type: #{condition_type}"
      false
    end
  rescue StandardError => e
    log_error "[TemplateExecutor] Error evaluating condition: #{e.message}"
    false
  end

  # Make HTTP request for api_call
  def make_http_request(url:, method:, headers: {}, body: nil)
    log_info "[TemplateExecutor] Making HTTP request: #{method} #{url}"

    options = {
      headers: headers,
      timeout: 30
    }

    # Add body for POST/PUT/PATCH requests
    if %w[POST PUT PATCH].include?(method) && body.present?
      options[:body] = body.is_a?(String) ? body : body.to_json
      options[:headers]['Content-Type'] ||= 'application/json'
    end

    response = HTTParty.send(method.downcase.to_sym, url, options)

    # Return parsed response
    {
      'status' => response.code,
      'headers' => response.headers.to_h,
      'body' => parse_response_body(response)
    }
  rescue StandardError => e
    log_error "[TemplateExecutor] HTTP request failed: #{e.message}"
    {
      'status' => 0,
      'error' => e.message
    }
  end

  # Parse response body (try JSON, fallback to string)
  def parse_response_body(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end

  # Get destination_id (Apple Messages user opaque ID) from conversation
  def destination_id
    contact = @conversation.contact
    destination_id_value = contact&.additional_attributes&.dig('apple_messages_source_id')

    log_error '[TemplateExecutor] Cannot send message - no apple_messages_source_id found' unless destination_id_value

    destination_id_value
  end

  # Logging helpers
  def log_info(message)
    Rails.logger.info message
  end

  def log_error(message)
    Rails.logger.error message
  end

  def log_warn(message)
    Rails.logger.warn message
  end

  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
# rubocop:enable Metrics/ClassLength
