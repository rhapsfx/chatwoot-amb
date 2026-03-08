# frozen_string_literal: true

module AppleMessagesForBusiness
  # Owns all bot state transitions, conversation attribute persistence,
  # retry counters, and the transition audit log.
  #
  # Responsibilities:
  #   - Validate that state transitions target known states
  #   - Persist bot_state + audit history (last 20 transitions) atomically
  #   - Expose conversation attribute read/write helpers used by the bot
  #   - Track retry counts per conversation
  class BotStateManager
    include BotLogging

    IDLE_TIMEOUT = 30.minutes

    # Every reachable state in the bot flow.
    # Attempting to transition to an unlisted state is logged and rejected.
    VALID_STATES = %w[
      AHA1 AHA2 AHA3
      AHB1 AHB1_2 AHB2 AHB3
      AHC1 AHC2 AHC3
      AHD1
      AHE1 AHE2
      AHF1 AHF1_skip AHF2 AHF3
      AHG1 AHG2
      AHH1 AHH2
      AHI1 AHI3 AHI4
      AHJ1 AHJ2 AHJ3 AHJ4
      AHK0 AHK1 AHK2 AHK3
      AH-restart
      DEMO_MODE DEMO_MODE_LARGE_FORM DEMO_MODE_AUTH_PROVIDER
      STOPPED
    ].freeze

    def initialize(conversation)
      @conversation = conversation
    end

    # Returns the current bot state, treating timed-out conversations as AHA1.
    def current_state
      attrs = @conversation.custom_attributes || {}
      last_updated = attrs['bot_state_updated_at']
      return 'AHA1' if last_updated && Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago

      attrs['bot_state'] || 'AHA1'
    end

    # Transitions to new_state with validation and audit trail.
    # Returns the new state (or the old state if validation fails).
    def update(new_state)
      unless VALID_STATES.include?(new_state)
        log_warn "[BotState] ⚠️ Rejected unknown state transition: #{current_state.inspect} → #{new_state.inspect}"
        return current_state
      end

      old_state = current_state
      attrs = @conversation.custom_attributes ||= {}

      attrs['bot_state'] = new_state
      attrs['bot_state_updated_at'] = Time.current.iso8601

      history = attrs['bot_state_history'] || []
      history << { 'from' => old_state, 'to' => new_state, 'at' => Time.current.iso8601 }
      attrs['bot_state_history'] = history.last(20)

      @conversation.save!
      log_info "[BotState] #{old_state} → #{new_state}"
      new_state
    end

    # Returns true when the conversation has been idle past IDLE_TIMEOUT.
    def timed_out?
      attrs = @conversation.custom_attributes || {}
      last_updated = attrs['bot_state_updated_at']
      return false unless last_updated

      Time.zone.parse(last_updated) < IDLE_TIMEOUT.ago
    end

    # Clears all flow-specific attributes and resets to AHA1 in a single save.
    # Used by reset_to_welcome for a fresh start.
    def full_reset
      attrs = @conversation.custom_attributes ||= {}

      %w[region customer_name stage_name delivery_address selected_guitar
         selected_timeslot selected_store].each { |k| attrs.delete(k) }

      attrs['retry_count'] = 0

      old_state = attrs['bot_state']
      attrs['bot_state'] = 'AHA1'
      attrs['bot_state_updated_at'] = Time.current.iso8601

      history = attrs['bot_state_history'] || []
      history << { 'from' => old_state, 'to' => 'AHA1', 'at' => Time.current.iso8601 }
      attrs['bot_state_history'] = history.last(20)

      @conversation.save!
      log_info '[BotState] full_reset → AHA1'
      'AHA1'
    end

    # === Conversation attribute helpers ===

    def get_attribute(key)
      (@conversation.custom_attributes || {})[key]
    end

    def set_attribute(key, value)
      @conversation.custom_attributes ||= {}
      @conversation.custom_attributes[key] = value
      @conversation.save!
    end

    # === Retry count helpers ===

    def increment_retry_count
      count = (get_attribute('retry_count') || 0) + 1
      set_attribute('retry_count', count)
      count
    end

    def reset_retry_count
      set_attribute('retry_count', 0)
    end
  end
end
