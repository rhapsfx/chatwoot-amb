# frozen_string_literal: true

module AppleMessagesForBusiness
  # Data-driven bot flow runtime engine.
  # Replaces the monolithic AcousticHouseBotService with a step-based
  # configuration system. Triggered when conversation.inbox.agent_bot&.flow?
  class BotFlowRuntimeService
    include BotLogging

    def initialize(conversation)
      @conversation = conversation
      @state_manager = BotStateManager.new(conversation)
      @sender = BotMessageSender.new(conversation)
      @agent_bot = @conversation.inbox.agent_bot
    end

    def process_message
      return unless @agent_bot&.flow?
      return unless @conversation.custom_attributes['bot_enabled'] != false

      current_step_id = @state_manager.get_attribute('current_step_id') || 'welcome'

      log_info "[BotFlow] Processing message - current_step: #{current_step_id}, conversation: #{@conversation.id}"

      step = find_step_by_id(current_step_id)
      return unless step

      execute_step(step)
    rescue StandardError => e
      log_error "[BotFlow] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    def process_interactive_response(interactive_data)
      return unless @agent_bot&.flow?

      current_step_id = @state_manager.get_attribute('current_step_id') || 'welcome'
      step = find_step_by_id(current_step_id)
      return unless step

      return unless step['step_type'] == 'decision'

      # Try to match the interactive response against the decision rules
      matched_step = match_decision(step, interactive_data)
      if matched_step
        navigate_to_step(matched_step['next_step_id'])
      elsif step['default_next_step_id']
        navigate_to_step(step['default_next_step_id'])
      end
    end

    def process_delayed_action(delayed_action_data)
      return unless @agent_bot&.flow?

      step_id = delayed_action_data['next_step_id']
      return unless step_id

      step = find_step_by_id(step_id)
      return unless step

      execute_step(step)
    end

    def execute_step(step)
      step_type = step['step_type']

      case step_type
      when 'message'
        execute_message_step(step)
      when 'decision'
        # Decisions don't send messages; they wait for user input
        update_state(step['id'])
      when 'action'
        execute_action_step(step)
      when 'wait'
        execute_wait_step(step)
      when 'ai'
        execute_ai_step(step)
      else
        log_error "[BotFlow] Unknown step type: #{step_type}"
      end
    end

    private

    attr_reader :conversation, :state_manager, :sender, :agent_bot

    # Find a step by ID from the flow_data
    def find_step_by_id(step_id)
      return nil unless flow_data

      flow_data.find { |s| s['id'] == step_id }
    end

    # Get the published flow's step definitions
    def flow_data
      published_flow = agent_bot.bot_flows.published.order(version: :desc).first
      return nil unless published_flow

      published_flow.flow_data || []
    end

    # Execute a message step by rendering and sending the message template
    def execute_message_step(step)
      template_id = step['message_template_id']
      return log_error("[BotFlow] No message_template_id for step: #{step['id']}") unless template_id

      # Use existing BotRendererService to render the template
      # The template is a MessageTemplate with AMB channel mapping
      template = MessageTemplate.find_by(
        account_id: conversation.account_id,
        name: template_id
      )

      return log_error("[BotFlow] Template '#{template_id}' not found") unless template

      log_info "[BotFlow] Sending template: #{template.name} (#{template.id})"

      # Render and send via BotMessageSender
      @sender.send_text_message(template.description)

      # Navigate to next step
      next_step_id = step['next_step_id']
      navigate_to_step(next_step_id) if next_step_id
    end

    # Match an interactive response against decision rules
    def match_decision(step, interactive_data)
      rules = step['rules'] || []

      rules.each do |rule|
        match_type = rule['match']['type']
        case match_type
        when 'keyword'
          return rule if match_keyword(rule, interactive_data)
        when 'interactive_id'
          return rule if match_interactive(rule, interactive_data)
        when 'form_field'
          return rule if match_form_field(rule, interactive_data)
        end
      end

      nil
    end

    def match_keyword(rule, interactive_data)
      return false unless interactive_data['data']

      keyword = rule['match']['value']
      user_input = interactive_data['data'].to_s.downcase

      if rule['match']['fuzzy']
        user_input.include?(keyword.downcase)
      else
        user_input == keyword
      end
    end

    def match_interactive(rule, interactive_data)
      return false unless interactive_data['data']

      expected = rule['match']['value']
      actual = interactive_data['data']['quick-reply']&.dig('selectedId') ||
               interactive_data['data']['selectedId']

      actual == expected
    end

    def match_form_field(rule, interactive_data)
      return false unless interactive_data['data']

      field_name = rule['match']['field_name']
      expected_value = rule['match']['value']

      # Form responses come from a nested structure
      selections = interactive_data.dig('data', 'selections') || []
      selection = selections.find { |s| s['field_name'] == field_name }

      return false unless selection

      selection_value = selection['value'].to_s
      if rule['match']['fuzzy']
        selection_value.downcase.include?(expected_value.downcase)
      else
        selection_value == expected_value
      end
    end

    # Execute an action step (assign team, add label, set attribute, etc.)
    def execute_action_step(step)
      action_type = step['action_type']
      params = step['parameters'] || {}

      log_info "[BotFlow] Executing action: #{action_type}"

      case action_type
      when 'assign_team'
        team_id = params['team_id']
        return log_error('[BotFlow] No team_id for assign_team action') unless team_id

        conversation.update!(team_id: team_id)
      when 'add_label'
        labels = params['labels'] || []
        conversation.update_labels(labels) if labels.any?
      when 'set_conversation_attribute'
        attr_key = params['key']
        attr_value = params['value']
        return log_error('[BotFlow] No key/value for set_conversation_attribute') unless attr_key && attr_value

        update_conversation_attribute(attr_key, attr_value)
      when 'send_webhook'
        execute_webhook_action(params)
      else
        log_error "[BotFlow] Unknown action type: #{action_type}"
      end

      # Navigate to next step
      next_step_id = step['next_step_id']
      navigate_to_step(next_step_id) if next_step_id
    end

    def execute_webhook_action(params)
      url = params['url']
      return log_error('[BotFlow] No URL for webhook action') unless url

      # Make HTTP request (configurable method, headers, etc.)
      begin
        HTTParty.post(url, body: params['body'], headers: params['headers'] || {})
      rescue StandardError => e
        log_error "[BotFlow] Webhook failed: #{e.message}"
      end
    end

    # Execute a wait step (delayed continuation)
    def execute_wait_step(step)
      delay_seconds = step['delay_seconds'] || 60

      log_info "[BotFlow] Waiting #{delay_seconds}s for step: #{step['id']}"

      next_step_id = step['next_step_id']
      return unless next_step_id

      # Schedule a delayed job to resume the flow
      AppleMessagesForBusiness::BotFlowDelayedActionJob.set(wait: delay_seconds.seconds).perform_later(
        conversation_id: conversation.id,
        next_step_id: next_step_id
      )
    end

    # Execute an AI step (LLM call)
    def execute_ai_step(step)
      instruction = step['instruction']
      return log_error('[BotFlow] No instruction for AI step') unless instruction

      # Call Captain LLM integration (Enterprise)
      log_info "[BotFlow] AI step: #{instruction}"

      # Get conversation history for context
      conversation.messages.order(created_at: :asc).last(10).pluck(:content, :message_type)

      begin
        # Use existing LLM service (Integrations::LlmBaseService or Captain service)
        # For now, just save the instruction as a conversation attribute
        update_conversation_attribute('ai_instruction', instruction)
      rescue StandardError => e
        log_error "[BotFlow] AI step failed: #{e.message}"
      end

      # Navigate to next step based on output_mode
      next_step_id = step['output_mode'] == 'decision' ? step['fallback_next_step_id'] : step['next_step_id']
      navigate_to_step(next_step_id) if next_step_id
    end

    # Update bot state to current_step_id
    def update_state(step_id)
      update_conversation_attribute('current_step_id', step_id)
    end

    # Navigate to a specific step (will be executed next)
    def navigate_to_step(step_id)
      return unless step_id

      step = find_step_by_id(step_id)
      return log_error("[BotFlow] Step '#{step_id}' not found") unless step

      log_info "[BotFlow] Navigating to step: #{step_id} (type: #{step['step_type']})"

      update_state(step_id)

      # Execute the step immediately if it's a message
      execute_step(step) if step['step_type'] == 'message'
    end

    # Helper: Update a conversation attribute
    def update_conversation_attribute(key, value)
      attrs = @conversation.custom_attributes ||= {}
      attrs[key] = value
      @conversation.save!
      log_info "[BotFlow] Updated attribute: #{key} = #{value}"
    rescue StandardError => e
      log_error "[BotFlow] Failed to update attribute: #{e.message}"
    end
  end
end
