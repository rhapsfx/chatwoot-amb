# frozen_string_literal: true

# Production service to execute bot flows with actual message sending
# Processes user messages through visual bot flows and sends real messages to Apple MSP
#
# Key Differences from FlowSimulatorService:
# - Sends actual messages via SendListPickerService, SendTimePickerService, etc.
# - Stores conversation state persistently
# - Handles real interactive responses
# - Used in production for real conversations
#
# Usage:
#   executor = AppleMessagesForBusiness::FlowExecutorService.new(flow, conversation, message)
#   result = executor.execute
#
class AppleMessagesForBusiness::FlowExecutorService
  include AppleMessagesForBusiness::Concerns::Utf8Logging
  attr_reader :flow, :conversation, :message, :executed_nodes

  def initialize(flow, conversation, message)
    @flow = flow
    @conversation = conversation
    @message = message
    @inbox = conversation.inbox
    @account = conversation.account
    @contact = conversation.contact
    @flow_data = flow.flow_data || {}
    @nodes = @flow_data['nodes'] || []
    @edges = @flow_data['edges'] || []
    @session = load_session_state
    @current_state = @session[:current_state] || find_initial_state
    @executed_nodes = []
  end

  # Execute flow for incoming message
  # @return [Hash] Execution result with :success, :nodes_executed, :state, :messages_sent
  def execute
    log_info "[FlowExecutor] 🚀 Executing flow '#{@flow.name}' for message: #{@message.content}"
    log_info "[FlowExecutor] 📍 Current state: #{@current_state}"

    # Check timeout FIRST before any processing
    if conversation_timed_out?
      log_info '[FlowExecutor] 🕐 Conversation timed out, resetting to welcome'
      reset_conversation_to_welcome
      return execute_welcome_state
    end

    # Check for attachments SECOND (after timeout check, before keyword/state processing)
    if @message.attachments.present?
      log_info "[FlowExecutor] 📎 Attachment detected (#{@message.attachments.count})"
      result = handle_attachment
      return result if result
    end

    # Check if this is an interactive message response (quick reply, list picker, etc.)
    interactive_value = extract_interactive_response_value

    # Normalize message - use interactive value if present, otherwise use content
    normalized_message = (interactive_value || @message.content).to_s.strip.downcase

    if interactive_value
      log_info "[FlowExecutor] 📱 Interactive response detected: #{interactive_value}"

      # Idempotency guard: Check if we've already processed this interaction
      if interaction_already_processed?(interactive_value)
        log_info '[FlowExecutor] 🔒 Interaction already processed, skipping'
        return { success: true, skipped: true, nodes_executed: [], current_state: @current_state, messages_sent: 0 }
      end

      # Mark interaction as processed
      mark_interaction_processed(interactive_value)
    end

    # Track execution
    @executed_nodes = []
    messages_sent = 0

    # Check for keyword matches first (intents)
    if (handler_node = find_intent_match(normalized_message))
      @executed_nodes << handler_node['id']
      log_info "[FlowExecutor] 🔑 Intent matched: #{handler_node.dig('data', 'label')} (Node ID: #{handler_node['id']})"
      log_info "[FlowExecutor] 🔍 Intent node data: #{handler_node['data'].inspect}"
      messages_sent = execute_intent_node(handler_node)
    elsif interactive_value && (waiting_intent = find_waiting_intent_for_interactive_response)
      # If no keyword match but this is an interactive response, check for a waiting intent node
      @executed_nodes << waiting_intent['id']
      log_info "[FlowExecutor] 📱 Matched waiting intent for interactive response: #{waiting_intent.dig('data', 'label')}"
      # Store the interactive value in conversation attributes for the next state to use
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes['last_interactive_value'] = interactive_value
      @conversation.save!
      messages_sent = execute_intent_node(waiting_intent)
    else
      # Process current state
      state_node = find_state_node(@current_state)
      if state_node
        @executed_nodes << state_node['id']
        log_info "[FlowExecutor] 📍 Processing state: #{state_node.dig('data', 'label')}"
        messages_sent = execute_state_node(state_node)
      else
        log_warn "[FlowExecutor] ⚠️ No matching state found for: #{@current_state}"
        # Send fallback message
        send_text_message(I18n.t('messages.activity.bot_flow.fallback_response'))
        messages_sent = 1
      end
    end

    # Save session state
    save_session_state

    log_info "[FlowExecutor] ✅ Execution complete. Nodes: #{@executed_nodes.count}, Messages: #{messages_sent}"

    {
      success: true,
      nodes_executed: @executed_nodes,
      current_state: @current_state,
      messages_sent: messages_sent
    }
  rescue StandardError => e
    log_error "[FlowExecutor] ❌ Execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    {
      success: false,
      error: e.message,
      nodes_executed: @executed_nodes,
      current_state: @current_state
    }
  end

  private

  # Extract value from interactive message responses (quick reply, list picker, etc.)
  # @return [String, nil] The selected identifier/value, or nil if not an interactive response
  def extract_interactive_response_value
    return nil if @message.content_attributes.blank?

    attrs = @message.content_attributes.with_indifferent_access

    # Interactive data is stored under the 'interactive_data' key by IncomingMessageService
    interactive_data = attrs['interactive_data']
    return nil unless interactive_data && interactive_data['data']

    data = interactive_data['data']

    # Check for different interactive response types
    # Quick Reply: data['quick-reply'] with items and selectedIndex
    if data['quick-reply'].present?
      quick_reply = data['quick-reply']
      if quick_reply['items'].present? && quick_reply['selectedIndex'].present?
        selected_index = quick_reply['selectedIndex']
        selected_item = quick_reply['items'][selected_index]
        return selected_item['identifier'] || selected_item['value'] if selected_item
      end
    end

    # List Picker: data['listPicker'] with sections
    if data['listPicker'].present?
      list_picker = data['listPicker']
      if list_picker['sections'].is_a?(Array)
        list_picker['sections'].each do |section|
          next unless section['items'].is_a?(Array)

          selected_item = section['items'].find { |item| item['selected'] == true }
          return selected_item['identifier'] || selected_item['value'] if selected_item
        end
      end
    end

    # Time Picker: data['timePicker'] or data['event'] with timeslots
    if data['timePicker'].present? || data['event'].present?
      time_picker = data['timePicker'] || data['event']
      if time_picker['timeslots'].is_a?(Array)
        selected_slot = time_picker['timeslots'].find { |slot| slot['selected'] == true }
        return selected_slot['identifier'] || selected_slot['duration'] if selected_slot
      end
    end

    # Form: data['dynamic'] with selections (would need more complex handling)

    nil
  end

  # Find an intent node that's waiting for an interactive response
  # This is used when there's no keyword match but we have an interactive response
  # @return [Hash, nil] The waiting intent node, or nil if none found
  def find_waiting_intent_for_interactive_response
    return nil unless @current_state

    current_state_node = @nodes.find do |n|
      n['type'] == 'state' && (n.dig('data', 'state_id') == @current_state || n['id'] == @current_state)
    end

    return nil unless current_state_node

    # Find the first intent node connected FROM current state
    # These are contextual intents waiting for user input
    waiting_intent_id = @edges
                        .select { |e| e['source'] == current_state_node['id'] }
                        .find { |e| @nodes.any? { |n| n['id'] == e['target'] && n['type'] == 'intent' } }
                        &.dig('target')

    return nil unless waiting_intent_id

    @nodes.find { |n| n['id'] == waiting_intent_id }
  end

  # Find initial state from flow
  def find_initial_state
    # Look for node marked as initial
    initial_node = @nodes.find { |n| n['type'] == 'state' && n.dig('data', 'is_initial') == true }
    return initial_node.dig('data', 'state_id') if initial_node

    # Filter out test nodes
    non_test_nodes = @nodes.reject { |n| n['id']&.to_s&.downcase&.include?('test') }

    # Fallback: first non-test state node with AHA pattern
    aha_state = non_test_nodes.find { |n| n['type'] == 'state' && n.dig('data', 'state_id')&.match?(/^AHA\d+$/i) }
    return aha_state.dig('data', 'state_id') if aha_state

    # Final fallback
    first_state = non_test_nodes.find { |n| n['type'] == 'state' }
    first_state&.dig('data', 'state_id') || 'AHA1'
  end

  # Find state node by state_id
  def find_state_node(state_id)
    @nodes.find do |n|
      n['type'] == 'state' && (n.dig('data', 'state_id') == state_id || n['id'] == state_id)
    end
  end

  # Find intent node that matches message
  # Optimized to check only relevant intents based on scope
  def find_intent_match(message)
    intents_to_check = []

    # Always check global intents (startover, stop, menu, help, reset)
    global_intents = @nodes.select do |n|
      n['type'] == 'intent' && (n.dig('data', 'scope') == 'global' || n.dig('data', 'scope').nil?)
    end
    intents_to_check.concat(global_intents)

    # Check contextual intents connected to current state
    if @current_state
      current_state_node = @nodes.find do |n|
        n['type'] == 'state' && (n.dig('data', 'state_id') == @current_state || n['id'] == @current_state)
      end

      if current_state_node
        # Find all intent nodes connected FROM current state
        contextual_intent_ids = @edges
                                .select { |e| e['source'] == current_state_node['id'] }
                                .pluck('target')

        contextual_intents = @nodes.select do |n|
          n['type'] == 'intent' &&
            n.dig('data', 'scope') == 'contextual' &&
            contextual_intent_ids.include?(n['id'])
        end

        intents_to_check.concat(contextual_intents)
      end
    end

    contextual_count = intents_to_check.length - global_intents.length
    log_info "[FlowExecutor] 🔍 Checking #{intents_to_check.length} intent nodes " \
             "(#{global_intents.length} global + #{contextual_count} contextual)"

    intents_to_check.find do |node|
      keywords = node.dig('data', 'keywords') || []
      exact_match = node.dig('data', 'exact_match')
      case_sensitive = node.dig('data', 'case_sensitive')

      log_info "[FlowExecutor] 🔎 Checking intent '#{node.dig('data', 'label')}': keywords=#{keywords.inspect}, exact_match=#{exact_match}"

      keywords.any? do |keyword|
        keyword_str = case_sensitive ? keyword.to_s : keyword.to_s.downcase
        message_str = case_sensitive ? message : message.downcase

        matched = if exact_match
                    # Exact match: entire message must equal keyword
                    keyword_str == message_str
                  else
                    # Word boundary match: keyword must be a complete word in message
                    # This prevents "ar" from matching "startover"
                    # Use \b word boundaries to match complete words only
                    regex = /\b#{Regexp.escape(keyword_str)}\b/
                    message_str.match?(regex)
                  end

        log_info "[FlowExecutor] ✅ Matched keyword '#{keyword}' in intent '#{node.dig('data', 'label')}'" if matched

        matched
      end
    end
  end

  # Execute intent node
  def execute_intent_node(node)
    messages_sent = 0

    log_info "[FlowExecutor] 🎯 Executing intent node: #{node['id']}"

    # Find outgoing edge
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }

    unless outgoing_edge
      log_warn '[FlowExecutor] ⚠️  Intent node has no outgoing edge!'
      return 0
    end

    log_info "[FlowExecutor] 🔗 Found outgoing edge to: #{outgoing_edge['target']}"

    target_node = find_node_by_id(outgoing_edge['target'])

    unless target_node
      log_error "[FlowExecutor] ❌ Target node '#{outgoing_edge['target']}' not found!"
      return 0
    end

    log_info "[FlowExecutor] 🎯 Target node type: #{target_node['type']}, label: #{target_node.dig('data', 'label')}"

    @executed_nodes << target_node['id']

    case target_node['type']
    when 'state'
      # Transition to state
      @current_state = target_node.dig('data', 'state_id') || target_node['id']
      log_info "[FlowExecutor] ➡️  Transitioning to state: #{@current_state}"
      messages_sent = execute_state_node(target_node)
    when 'template'
      # Send template
      log_info '[FlowExecutor] 📤 Sending template from intent'
      messages_sent = execute_template_node(target_node)
    when 'action'
      # Execute action
      log_info '[FlowExecutor] ⚙️  Executing action from intent'
      messages_sent = execute_action_node(target_node)
    else
      log_warn "[FlowExecutor] ⚠️  Unknown target node type: #{target_node['type']}"
    end

    messages_sent
  end

  # Execute state node
  def execute_state_node(node)
    state_data = node['data'] || {}
    state_id = state_data['state_id'] || node['id']
    handler = state_data['handler']
    actions = state_data['actions'] || []
    messages_sent = 0

    log_info "[FlowExecutor] 🎬 Executing state node: #{state_id}"

    # Execute handler method if present
    if handler.present?
      log_info "[FlowExecutor] 🔧 Executing handler: #{handler}"
      messages_sent += execute_handler_method(handler)
    end

    # Execute actions (can contain template references)
    actions.each_with_index do |action, index|
      messages_sent += execute_action(action)

      # Add delay between actions (except after last action)
      if index < actions.length - 1
        log_info '[FlowExecutor] ⏱️  Waiting between actions (1.5s delay)'
        sleep 1.5
      end
    end

    # Handle transitions - automatically follow edges to next state
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node && target_node['type'] == 'state'
        @current_state = target_node.dig('data', 'state_id') || target_node['id']
        log_info "[FlowExecutor] ➡️ Auto-transitioning to state: #{@current_state}"

        # CRITICAL: Actually execute the target node to continue the flow
        # This enables automatic handler chaining via visual edges
        log_info '[FlowExecutor] 🎬 Executing target state node after transition'
        @executed_nodes << target_node['id']
        messages_sent += execute_state_node(target_node)
      end
    end

    messages_sent
  end

  # Execute handler method with 4-tier fallback system
  # Priority 1: Template reference (format: "template:123")
  # Priority 2: Template by name
  # Priority 3: Handler metadata (existing system) - SKIPPED for handlers with chaining
  # Priority 4: Direct service call (for complex handlers with chaining logic)
  def execute_handler_method(handler_name)
    log_info "[FlowExecutor] 🔍 Looking for handler: #{handler_name}"

    # PRIORITY 1: Check if handler is a template reference (format: "template:123")
    if handler_name.to_s.start_with?('template:')
      template_id = handler_name.sub('template:', '').to_i
      template = BotActionTemplate.find_by(id: template_id, account: @account)

      if template
        log_info "[FlowExecutor] 📋 Found template reference: #{template.name} (ID: #{template_id})"
        return execute_template(template)
      else
        log_error "[FlowExecutor] ❌ Template not found: #{template_id}"
      end
    end

    # PRIORITY 2: Check for template by name
    template = BotActionTemplate.find_by(account: @account, name: handler_name)
    if template
      log_info "[FlowExecutor] 📋 Found template by name: #{template.name}"
      return execute_template(template)
    end

    # PRIORITY 3: SKIP metadata for handlers with known chaining logic
    # These handlers call other handlers and must execute their actual code
    # Using metadata would break the chaining behavior
    handlers_with_chaining = [
      :handle_welcome,  # calls handle_region_prompt
      :handle_region_selection,  # calls handle_form_or_name_prompt
      :handle_form_response,  # calls handle_name_preference_prompt
      :handle_guitar_selection,  # calls handle_ar_introduction
      :handle_ar_introduction,  # calls handle_ar_first_question
      :handle_apple_pay_response,  # calls handle_lesson_introduction
      :handle_lesson_introduction,  # calls handle_location_request
      :handle_time_picker_response,  # calls handle_continue_prompt
      :handle_summary,  # calls handle_final_message
      :handle_start_over,  # calls handle_welcome
      :handle_menu_selection  # calls multiple handlers based on selection
    ]

    # Check for handler metadata BUT skip if handler has chaining logic
    handler_metadata = AppleMessagesForBusiness::AcousticHouseBotService.handler_methods_metadata[handler_name.to_sym]
    if handler_metadata && handlers_with_chaining.exclude?(handler_name.to_sym)
      log_info '[FlowExecutor] 📋 Handler metadata found (using templates)'
      return execute_handler_via_metadata(handler_name, handler_metadata)
    elsif handler_metadata && handlers_with_chaining.include?(handler_name.to_sym)
      log_info "[FlowExecutor] ⚠️  Handler #{handler_name} has chaining logic - skipping metadata, using direct call"
    end

    # PRIORITY 4: Direct service call (for complex handlers)
    log_info "[FlowExecutor] 🎯 Using direct service call for handler: #{handler_name}"
    execute_handler_via_service(handler_name)
  end

  # Execute BotActionTemplate using TemplateExecutorService
  def execute_template(template)
    log_info "[FlowExecutor] 📋 Executing template: #{template.name} (Type: #{template.template_type})"

    executor = AppleMessagesForBusiness::TemplateExecutorService.new(
      template: template,
      conversation: @conversation,
      message: @message
    )

    messages_sent = executor.execute
    log_info "[FlowExecutor] ✅ Template executed: #{template.name}, messages sent: #{messages_sent}"

    messages_sent
  end

  # Execute handler using metadata (template-based)
  def execute_handler_via_metadata(handler_name, handler_metadata)
    # Get template names from dependencies
    template_names = handler_metadata.dig(:dependencies, :templates) || []
    log_info "[FlowExecutor] 📋 Handler has #{template_names.length} templates: #{template_names.inspect}"

    if template_names.empty?
      log_warn "[FlowExecutor] ⚠️  No templates defined for handler: #{handler_name}"
      return 0
    end

    messages_sent = 0

    template_names.each_with_index do |template_name, index|
      log_info "[FlowExecutor] 🔎 Looking for template: #{template_name}"
      template = find_template(template_name)

      unless template
        log_error "[FlowExecutor] ❌ Template not found: #{template_name}"
        next
      end

      log_info "[FlowExecutor] ✅ Template found: #{template.name} (ID: #{template.id})"
      messages_sent += send_template(template)

      # Add delay between messages to ensure proper delivery order
      if index < template_names.length - 1
        log_info '[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)'
        sleep 1.5
      end
    end

    messages_sent
  end

  # Execute handler by calling method directly on AcousticHouseBotService
  def execute_handler_via_service(handler_name)
    # Instantiate AcousticHouseBotService to call the handler method
    # This allows us to reuse existing handler logic
    bot_service = AppleMessagesForBusiness::AcousticHouseBotService.new(
      @conversation,
      @message,
      @flow.agent_bot,
      @flow.agent_bot.bot_config
    )

    # Check if method exists
    unless bot_service.respond_to?(handler_name.to_sym, true)
      log_error "[FlowExecutor] ❌ Handler method '#{handler_name}' not found in AcousticHouseBotService"
      return 0
    end

    # Call the handler method
    log_info "[FlowExecutor] 🎯 Calling #{handler_name} on AcousticHouseBotService"

    begin
      # Call the handler - it will send messages directly via its own methods
      bot_service.send(handler_name.to_sym)

      # Count messages sent by checking conversation messages created after this point
      # Note: This is approximate since we can't easily track messages from the service
      log_info '[FlowExecutor] ✅ Handler executed successfully'
      1 # Return 1 to indicate handler was called (actual message count may vary)
    rescue StandardError => e
      log_error "[FlowExecutor] ❌ Error calling handler: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      0
    end
  end

  # Execute action
  def execute_action(action)
    action_type = action['type']

    case action_type
    when 'execute_template'
      # Action directly specifies a template ID
      template_id = action['template_id']
      template = BotActionTemplate.find_by(id: template_id, account: @account)

      if template
        execute_template(template)
      else
        log_error "[FlowExecutor] ❌ Template not found: #{template_id}"
        0
      end
    when 'execute_templates'
      # Execute multiple templates in sequence
      template_ids = action['template_ids'] || []
      messages_sent = 0

      template_ids.each_with_index do |tmpl_id, index|
        template = BotActionTemplate.find_by(id: tmpl_id, account: @account)

        if template
          messages_sent += execute_template(template)

          # Add delay between templates (except after last)
          if index < template_ids.length - 1
            log_info '[FlowExecutor] ⏱️  Waiting between templates (1.5s delay)'
            sleep 1.5
          end
        else
          log_error "[FlowExecutor] ❌ Template not found: #{tmpl_id}"
        end
      end

      messages_sent
    when 'execute_handler'
      # Legacy handler execution
      handler_name = action['handler_name']
      execute_handler_method(handler_name)
    when 'execute_custom_code'
      # Execute custom code handler from AcousticHouseBotService
      execute_custom_code_action(action)
    when 'send_template'
      template_name = action['template_name']
      template = find_template(template_name)
      return 0 unless template

      messages_sent = send_template(template)

      # Add delay after sending template with potential attachments
      log_info '[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)'
      sleep 1.5

      messages_sent
    when 'send_text'
      send_text_message(action['text'])
      # No delay for simple text messages
      1
    when 'send_oauth', 'execute_oauth'
      # OAuth authentication action
      execute_oauth_action(action)
    else
      log_warn "[FlowExecutor] ⚠️ Unknown action type: #{action_type}"
      0
    end
  end

  # Execute template node
  def execute_template_node(node)
    template_data = node['data'] || {}
    template_name = template_data['template_name']

    template = find_template(template_name)
    return 0 unless template

    messages_sent = send_template(template)

    # Follow edge to next state
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node && target_node['type'] == 'state'
        @current_state = target_node.dig('data', 'state_id') || target_node['id']
        log_info "[FlowExecutor] ➡️ Transitioned to state: #{@current_state}"
      end
    end

    messages_sent
  end

  # Execute action node
  def execute_action_node(node)
    node['data'] || {}
    messages_sent = 0

    # For now, action nodes just transition to next node
    outgoing_edge = @edges.find { |e| e['source'] == node['id'] }
    if outgoing_edge
      target_node = find_node_by_id(outgoing_edge['target'])
      if target_node
        @executed_nodes << target_node['id']

        case target_node['type']
        when 'state'
          @current_state = target_node.dig('data', 'state_id') || target_node['id']
          messages_sent = execute_state_node(target_node)
        end
      end
    end

    messages_sent
  end

  # Find template by name
  def find_template(template_name)
    log_info "[FlowExecutor] 🔎 Searching for template: '#{template_name}' in account #{@account.id}"

    template = MessageTemplate
               .where(account: @account, name: template_name)
               .where('? = ANY(supported_channels)', 'apple_messages_for_business')
               .first

    if template
      log_info "[FlowExecutor] ✅ Found template: '#{template.name}' (ID: #{template.id})"
    else
      log_error "[FlowExecutor] ❌ Template '#{template_name}' not found in account #{@account.id}"
      available_templates = MessageTemplate
                            .where(account: @account)
                            .where('? = ANY(supported_channels)', 'apple_messages_for_business')
                            .pluck(:name)
                            .join(', ')
      log_error "[FlowExecutor] 💡 Available templates: #{available_templates}"
    end

    template
  end

  # Send template based on its type
  def send_template(template)
    log_info "[FlowExecutor] 📤 Preparing to send template: #{template.name} (ID: #{template.id})"

    # Use TemplateFacade to load template data with images
    facade = AppleMessagesForBusiness::TemplateFacade.new(template)

    # Detect template type
    block_type = if template.content_blocks.any?
                   template.content_blocks.first.block_type
                 else
                   template.send(:detect_block_type_from_metadata)
                 end

    log_info "[FlowExecutor] 📝 Template type: #{block_type}"

    # Load template data with images included
    template_data = facade.load_data_with_images(block_type)
    log_info "[FlowExecutor] 📦 Template data loaded: #{template_data.keys.join(', ')}"

    # Map block_type to content_type
    content_type = case block_type
                   when 'list_picker' then 'apple_list_picker'
                   when 'time_picker' then 'apple_time_picker'
                   when 'form', 'apple_form' then 'apple_form'
                   when 'rich_link' then 'apple_rich_link'
                   else 'text'
                   end

    log_info "[FlowExecutor] 🏷️  Content type: #{content_type}"

    # Create outgoing message via MessageBuilder
    # This will automatically trigger after_commit callbacks that send the message
    log_info '[FlowExecutor] 🔨 Creating message via MessageBuilder...'

    message = Messages::MessageBuilder.new(
      nil, # user (bot context, no specific user)
      @conversation,
      {
        content: template_data['text'] || template.name,
        message_type: :outgoing,
        content_type: content_type,
        content_attributes: template_data,
        sender: @flow.agent_bot
      }
    ).perform

    log_info "[FlowExecutor] ✅ Message created (ID: #{message.id}) and queued for sending"
    1
  rescue StandardError => e
    log_error "[FlowExecutor] ❌ Failed to send template: #{e.message}"
    log_error "[FlowExecutor] 🔍 Error class: #{e.class.name}"
    Rails.logger.error e.backtrace.join("\n")
    0
  end

  # Send simple text message
  def send_text_message(text)
    mb = Messages::MessageBuilder.new(
      nil, # user (bot context)
      @conversation,
      {
        content: text,
        message_type: :outgoing,
        sender: @flow.agent_bot
      }
    )
    mb.perform
  end

  # Helper: Find node by ID
  def find_node_by_id(node_id)
    @nodes.find { |n| n['id'] == node_id }
  end

  # Load session state from conversation
  def load_session_state
    # Try to load from conversation additional_attributes
    attrs = @conversation.additional_attributes || {}
    bot_session = attrs['bot_session'] || {}

    {
      current_state: bot_session['current_state'],
      message_count: bot_session['message_count'] || 0,
      retry_count: bot_session['retry_count'] || 0,
      last_update: bot_session['last_update'] || bot_session['last_updated_at']
    }.symbolize_keys
  end

  # Save session state to conversation
  def save_session_state
    attrs = @conversation.additional_attributes || {}
    attrs['bot_session'] ||= {}

    # Preserve retry_count if it exists
    retry_count = attrs.dig('bot_session', 'retry_count') || @session[:retry_count] || 0

    attrs['bot_session'] = {
      'current_state' => @current_state,
      'message_count' => (@session[:message_count] || 0) + 1,
      'last_update' => Time.current.iso8601,
      'last_updated_at' => Time.current.iso8601,
      'retry_count' => retry_count,
      'flow_id' => @flow.id,
      'flow_name' => @flow.name
    }

    @conversation.update!(additional_attributes: attrs)
  end

  # ============================================================================
  # RETRY COUNTER MANAGEMENT (Section 6.1)
  # ============================================================================

  # Increment retry count for current state
  # @return [Integer] The new retry count
  def increment_retry_count
    session = load_session_state
    session[:retry_count] ||= 0
    session[:retry_count] += 1
    save_session_state_with_retry(session)
    session[:retry_count]
  end

  # Get current retry count
  # @return [Integer] The current retry count
  def retry_count
    session = load_session_state
    session[:retry_count] || 0
  end

  # Reset retry count to zero
  def reset_retry_count
    session = load_session_state
    session[:retry_count] = 0
    save_session_state_with_retry(session)
  end

  # Save session state with retry count
  def save_session_state_with_retry(session)
    attrs = @conversation.additional_attributes || {}
    attrs['bot_session'] ||= {}
    attrs['bot_session']['retry_count'] = session[:retry_count]
    attrs['bot_session']['last_updated_at'] = Time.current.iso8601
    @conversation.update!(additional_attributes: attrs)
  end

  # ============================================================================
  # TIMEOUT DETECTION & AUTO-RESET (Section 6.1)
  # ============================================================================

  # Check if conversation has timed out (30 minutes of inactivity)
  # @return [Boolean] true if conversation has timed out
  def conversation_timed_out?
    session = load_session_state
    last_updated = session[:last_update]
    return false unless last_updated

    timeout = 30.minutes
    Time.zone.parse(last_updated) < timeout.ago
  rescue ArgumentError
    log_warn "[FlowExecutor] ⚠️ Invalid timestamp in session: #{last_updated}"
    false
  end

  # Reset conversation to welcome state and clear all attributes
  def reset_conversation_to_welcome
    log_info '[FlowExecutor] 🔄 Resetting conversation to welcome state'

    # Clear all conversation attributes
    @conversation.custom_attributes = {}
    @conversation.save!

    # Reset session state
    attrs = @conversation.additional_attributes || {}
    attrs['bot_session'] = {
      'current_state' => find_initial_state,
      'message_count' => 0,
      'retry_count' => 0,
      'last_updated_at' => Time.current.iso8601
    }
    @conversation.update!(additional_attributes: attrs)

    # Update local state
    @current_state = find_initial_state
    @session = load_session_state
  end

  # Execute welcome state after timeout reset
  def execute_welcome_state
    log_info '[FlowExecutor] 👋 Executing welcome state after timeout'

    # Find welcome/initial state node
    welcome_node = find_state_node(@current_state)
    return { success: false, error: 'Welcome state not found' } unless welcome_node

    @executed_nodes << welcome_node['id']
    messages_sent = execute_state_node(welcome_node)

    save_session_state

    {
      success: true,
      nodes_executed: @executed_nodes,
      current_state: @current_state,
      messages_sent: messages_sent,
      timeout_reset: true
    }
  end

  # ============================================================================
  # IDEMPOTENCY GUARDS (Section 6.1)
  # ============================================================================

  # Check if an interaction has already been processed
  # @param [String] interactive_value The interaction identifier
  # @return [Boolean] true if already processed
  def interaction_already_processed?(interactive_value)
    cache_key = generate_interaction_cache_key(interactive_value)
    Rails.cache.read(cache_key).present?
  end

  # Mark an interaction as processed
  # @param [String] interactive_value The interaction identifier
  def mark_interaction_processed(interactive_value)
    cache_key = generate_interaction_cache_key(interactive_value)
    # Store for 2 minutes to prevent duplicate processing
    Rails.cache.write(cache_key, '1', expires_in: 2.minutes)
    log_info "[FlowExecutor] 🔐 Marked interaction as processed: #{cache_key}"
  end

  # Generate cache key for interaction idempotency
  # @param [String] interactive_value The interaction identifier
  # @return [String] The cache key
  def generate_interaction_cache_key(interactive_value)
    # Create hash of conversation ID and interaction data
    interaction_hash = Digest::MD5.hexdigest("#{@conversation.id}:#{interactive_value}")
    "flow_executor:#{@flow.id}:interaction:#{interaction_hash}"
  end

  # ============================================================================
  # CUSTOM CODE EXECUTION (Section 6.2)
  # ============================================================================

  # Execute custom code handler from AcousticHouseBotService
  # This allows Bot Studio state nodes to execute Ruby code from the legacy service
  # Enables complex logic like form parsing, geocoding, retry logic, etc.
  # @param [Hash] action The action configuration with handler name
  # @return [Integer] Number of messages sent (approximate)
  def execute_custom_code_action(action)
    handler_name = action['handler']

    if handler_name.blank?
      log_error '[FlowExecutor] ❌ execute_custom_code action missing handler name'
      return 0
    end

    # Create AcousticHouseBotService instance
    service = AppleMessagesForBusiness::AcousticHouseBotService.new(
      @conversation,
      @message,
      @flow.agent_bot,
      @flow.agent_bot.bot_config
    )

    # Check if handler exists
    unless service.respond_to?(handler_name.to_sym, true)
      log_error "[FlowExecutor] ❌ Custom handler '#{handler_name}' not found in AcousticHouseBotService"
      return 0
    end

    # Invoke handler using send
    log_info "[FlowExecutor] 🔧 Executing custom handler: #{handler_name}"

    begin
      result = service.send(handler_name.to_sym)
      log_info "[FlowExecutor] ✅ Custom handler executed successfully: #{handler_name}"

      # Check if handler requested a state transition
      if result.is_a?(Hash) && result[:transition_to]
        target_state = result[:transition_to]
        log_info "[FlowExecutor] 🔀 Handler requested transition to: #{target_state}"

        # Update current state
        @conversation.custom_attributes ||= {}
        @conversation.custom_attributes['current_state'] = target_state
        @conversation.save!

        # Find and execute the target state
        target_node = @flow_data['nodes'].find { |n| n['id'] == target_state }
        if target_node
          log_info "[FlowExecutor] ➡️ Transitioning to state: #{target_state}"
          return execute_state_node(target_node)
        else
          log_error "[FlowExecutor] ❌ Target state not found: #{target_state}"
          return 0
        end
      end

      1 # Return 1 to indicate handler was called (actual message count may vary)
    rescue StandardError => e
      log_error "[FlowExecutor] ❌ Error executing custom handler #{handler_name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      0
    end
  end

  # ============================================================================
  # OAUTH AUTHENTICATION INTEGRATION (Section 6.7)
  # ============================================================================

  # Execute OAuth authentication action
  # Sends OAuth authentication request to Apple Business Chat
  # @param [Hash] action Action configuration with provider
  # @return [Integer] Number of messages sent (1 if successful, 0 if failed)
  def execute_oauth_action(action)
    provider = action['provider']

    log_info "[FlowExecutor] 🔐 Executing OAuth authentication for provider: #{provider}"

    # Check if provider is enabled
    unless @conversation.inbox.channel.oauth2_provider_enabled?(provider)
      log_warn "[FlowExecutor] ⚠️ OAuth provider '#{provider}' is not enabled for this inbox"
      send_text_message(I18n.t('messages.activity.bot_flow.oauth.provider_not_enabled', provider: provider.capitalize))
      return 1
    end

    # Build authentication data
    authentication_data = { 'provider' => provider }
    message_content = I18n.t('messages.activity.bot_flow.oauth.sign_in_prompt', provider: provider.capitalize)

    log_info '[FlowExecutor] 📤 Sending OAuth authentication request to Apple MSP'

    # Use SendAuthenticationService to send OAuth request
    service = AppleMessagesForBusiness::SendAuthenticationService.new(
      channel: @conversation.inbox.channel,
      destination_id: @conversation.contact_inbox.source_id,
      authentication_data: authentication_data,
      message_content: message_content
    )

    result = service.perform

    if result[:success]
      log_info '[FlowExecutor] ✅ OAuth authentication sent successfully'
      1
    else
      log_error "[FlowExecutor] ❌ OAuth authentication failed: #{result[:error]}"
      send_text_message(I18n.t('messages.activity.bot_flow.oauth.unavailable'))
      0
    end
  rescue StandardError => e
    log_error "[FlowExecutor] ❌ Error executing OAuth action: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    send_text_message(I18n.t('messages.activity.bot_flow.oauth.unavailable'))
    0
  end

  # ============================================================================
  # ATTACHMENT HANDLING (Section 6.6)
  # ============================================================================

  # Handle incoming attachments (photos, files, etc.)
  # @return [Hash, nil] Execution result if attachment was handled, nil otherwise
  def handle_attachment
    # Check if current state expects attachments
    current_node = find_current_state_node
    unless current_node
      log_warn '[FlowExecutor] ⚠️ No current state node found for attachment handling'
      return nil
    end

    attachment_handler = current_node.dig('data', 'attachment_handler')
    unless attachment_handler
      log_info '[FlowExecutor] 📎 Current state does not handle attachments, continuing normal flow'
      return nil
    end

    log_info "[FlowExecutor] 📎 Current state has attachment handler: #{attachment_handler}"

    # Check for image attachments
    has_image = @message.attachments.any? do |attachment|
      attachment.file&.content_type&.start_with?('image/')
    end

    if has_image && attachment_handler == 'handle_photo_upload'
      log_info '[FlowExecutor] 📸 Photo upload detected, processing'
      send_text_message(I18n.t('messages.activity.bot_flow.attachment.photo_received'))

      # Find next state
      next_state = current_node.dig('data', 'attachment_next_state')
      if next_state
        log_info "[FlowExecutor] ➡️ Transitioning to next state: #{next_state}"
        transition_to_state(next_state)
      else
        log_warn '[FlowExecutor] ⚠️ No attachment_next_state configured'
      end

      # Save session state
      save_session_state

      {
        success: true,
        attachment_handled: true,
        nodes_executed: [current_node['id']],
        current_state: @current_state,
        messages_sent: 1
      }
    else
      log_info "[FlowExecutor] 📎 Attachment type or handler mismatch (has_image: #{has_image}, handler: #{attachment_handler})"
      nil
    end
  end

  # Find the current state node
  # @return [Hash, nil] The current state node, or nil if not found
  def find_current_state_node
    return nil unless @current_state

    @nodes.find do |n|
      n['type'] == 'state' && (n.dig('data', 'state_id') == @current_state || n['id'] == @current_state)
    end
  end

  # Transition to a new state
  # @param [String] state_id The target state ID
  def transition_to_state(state_id)
    @current_state = state_id
    log_info "[FlowExecutor] 🔄 State transitioned to: #{state_id}"
  end

  # ============================================================================
  # ADVANCED CONDITION TYPES (Section 6.3)
  # ============================================================================

  # Evaluate condition node and return result
  # @param [Hash] condition_node The condition node to evaluate
  # @return [Boolean, String, nil] Condition result (boolean, target node ID, or nil)
  def evaluate_condition(condition_node)
    condition_type = condition_node.dig('data', 'condition_type')

    case condition_type
    when 'capability_check'
      evaluate_capability_condition(condition_node)
    when 'count_check'
      evaluate_count_condition(condition_node)
    when 'comparison'
      evaluate_comparison_condition(condition_node)
    when 'time_check'
      evaluate_time_condition(condition_node)
    else
      log_warn "[FlowExecutor] ⚠️ Unknown condition type: #{condition_type}"
      false
    end
  end

  # Evaluate capability check condition
  # Checks if contact has specific Apple Messages capability (FORM, AR, etc.)
  # @param [Hash] condition_node The condition node
  # @return [Boolean] true if contact has the capability
  def evaluate_capability_condition(condition_node)
    capability = condition_node.dig('data', 'capability')
    contact = @conversation.contact
    capabilities = contact.additional_attributes&.dig('apple_messages_capabilities') || ''

    has_capability = capabilities.include?(capability)
    log_info "[FlowExecutor] 🔍 Capability check: #{capability} = #{has_capability}"

    has_capability
  end

  # Evaluate count check condition
  # Evaluates count of items in conversation attribute and routes to different targets
  # Supports ranges (2..5), exact values (1), and thresholds (6+)
  # @param [Hash] condition_node The condition node
  # @return [String, nil] Target node ID based on count
  def evaluate_count_condition(condition_node)
    variable = condition_node.dig('data', 'variable')
    value = get_conversation_attribute(variable)

    # Parse value to get count
    count = if value.is_a?(String) && value.start_with?('[')
              begin
                JSON.parse(value).length
              rescue JSON::ParserError
                log_warn "[FlowExecutor] ⚠️ Failed to parse JSON array: #{value}"
                0
              end
            elsif value.is_a?(Array)
              value.length
            else
              value.to_i
            end

    log_info "[FlowExecutor] 🔢 Count check: #{variable} = #{count}"

    # Find matching route
    routes = condition_node.dig('data', 'routes') || {}

    routes.each do |range_str, target|
      matched = if range_str.include?('..')
                  # Range: "2..5"
                  range = eval(range_str) # rubocop:disable Security/Eval
                  range.include?(count)
                elsif range_str.include?('+')
                  # "6+" means >= 6
                  threshold = range_str.to_i
                  count >= threshold
                else
                  # Exact: "1"
                  count == range_str.to_i
                end

      if matched
        log_info "[FlowExecutor] ✅ Count matched route: #{range_str} → #{target}"
        return target
      end
    end

    log_warn "[FlowExecutor] ⚠️ No route matched for count: #{count}"
    nil
  end

  # Evaluate comparison condition
  # Compares conversation attribute value with threshold
  # Supports operators: >=, >, <=, <, ==
  # @param [Hash] condition_node The condition node
  # @return [Boolean] Comparison result
  def evaluate_comparison_condition(condition_node)
    variable = condition_node.dig('data', 'variable')
    operator = condition_node.dig('data', 'operator')
    threshold = condition_node.dig('data', 'value')

    value = get_conversation_attribute(variable)

    result = case operator
             when '>=' then value.to_i >= threshold.to_i
             when '>' then value.to_i > threshold.to_i
             when '<=' then value.to_i <= threshold.to_i
             when '<' then value.to_i < threshold.to_i
             when '==' then value.to_s == threshold.to_s
             else
               log_warn "[FlowExecutor] ⚠️ Unknown operator: #{operator}"
               false
             end

    log_info "[FlowExecutor] 🔍 Comparison: #{variable} (#{value}) #{operator} #{threshold} = #{result}"

    result
  end

  # Evaluate time check condition
  # Checks if timestamp is older than threshold
  # @param [Hash] condition_node The condition node
  # @return [Boolean] true if timestamp is older than threshold
  def evaluate_time_condition(condition_node)
    variable = condition_node.dig('data', 'variable')
    threshold_str = condition_node.dig('data', 'threshold') # "30_minutes"

    timestamp = get_conversation_attribute(variable)
    unless timestamp
      log_warn "[FlowExecutor] ⚠️ No timestamp found for variable: #{variable}"
      return false
    end

    # Parse threshold (e.g., "30_minutes" → 30.minutes)
    threshold = begin
      eval(threshold_str) # rubocop:disable Security/Eval
    rescue StandardError => e
      log_error "[FlowExecutor] ❌ Failed to parse threshold: #{threshold_str} (#{e.message})"
      return false
    end

    # Check if timestamp is older than threshold
    is_older = Time.zone.parse(timestamp) < threshold.ago
    log_info "[FlowExecutor] ⏰ Time check: #{variable} (#{timestamp}) older than #{threshold_str}? #{is_older}"

    is_older
  rescue ArgumentError => e
    log_error "[FlowExecutor] ❌ Invalid timestamp format: #{timestamp} (#{e.message})"
    false
  end

  # Get conversation attribute value
  # @param [String] attribute_name The attribute name
  # @return [String, nil] The attribute value
  def get_conversation_attribute(attribute_name)
    # Check both custom_attributes and additional_attributes
    value = @conversation.custom_attributes&.dig(attribute_name)
    value ||= @conversation.additional_attributes&.dig(attribute_name)
    value ||= @conversation.additional_attributes&.dig('bot_session', attribute_name)

    value
  end

  # Logging helpers provided by Utf8Logging concern
  # - log_info, log_warn, log_error, log_debug are now UTF-8 safe
end
