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

    # Normalize message
    normalized_message = @message.content.to_s.strip.downcase

    # Track execution
    @executed_nodes = []
    messages_sent = 0

    # Check for keyword matches first (intents)
    if (handler_node = find_intent_match(normalized_message))
      @executed_nodes << handler_node['id']
      log_info "[FlowExecutor] 🔑 Intent matched: #{handler_node.dig('data', 'label')} (Node ID: #{handler_node['id']})"
      log_info "[FlowExecutor] 🔍 Intent node data: #{handler_node['data'].inspect}"
      messages_sent = execute_intent_node(handler_node)
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
        send_text_message("I'm not sure how to respond to that.")
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
                                .map { |e| e['target'] }

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

    # Handle transitions
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

  # Execute handler method with 4-tier fallback system
  # Priority 1: Template reference (format: "template:123")
  # Priority 2: Template by name
  # Priority 3: Handler metadata (existing system)
  # Priority 4: Direct service call (deprecated)
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

    # PRIORITY 3: Check for handler metadata (existing system)
    handler_metadata = AppleMessagesForBusiness::AcousticHouseBotService.handler_methods_metadata[handler_name.to_sym]
    if handler_metadata
      log_info '[FlowExecutor] 📋 Handler metadata found (legacy)'
      return execute_handler_via_metadata(handler_name, handler_metadata)
    end

    # PRIORITY 4: Fallback to direct service call (deprecated)
    log_warn "[FlowExecutor] ⚠️  Using deprecated handler method: #{handler_name}"
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
      last_update: bot_session['last_update']
    }.symbolize_keys
  end

  # Save session state to conversation
  def save_session_state
    attrs = @conversation.additional_attributes || {}
    attrs['bot_session'] = {
      'current_state' => @current_state,
      'message_count' => (@session[:message_count] || 0) + 1,
      'last_update' => Time.current.iso8601,
      'flow_id' => @flow.id,
      'flow_name' => @flow.name
    }

    @conversation.update!(additional_attributes: attrs)
  end

  # Logging helpers
  def log_info(message)
    Rails.logger.info message
  end

  def log_warn(message)
    Rails.logger.warn message
  end

  def log_error(message)
    Rails.logger.error message
  end
end
