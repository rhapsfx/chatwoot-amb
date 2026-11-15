class AppleMessagesForBusiness::SendInvitationService
  AMB_SERVER = 'https://mspgw.push.apple.com/v1'.freeze

  pattr_initialize [:inbox!, :destination_id!, :template_id!, :reference_id!, :parameters!, :locale]

  def perform
    validate_reference_id!
    check_opt_out!
    message_id = SecureRandom.uuid
    payload = build_payload(message_id)
    response = send_to_apple(payload, message_id)

    return { success: true, response: response } if response.success?

    handle_failure(response)
  rescue StandardError => e
    Rails.logger.error "[AMB Invitation] Failed for #{destination_id}: #{e.message}"
    { success: false, error: e.message }
  end

  private

  # Spec: referenceId is required, max 1000 chars, and must not contain quote/apostrophe characters.
  def validate_reference_id!
    raise ArgumentError, 'reference_id is required' if reference_id.blank?
    raise ArgumentError, 'reference_id must not exceed 1000 characters' if reference_id.to_s.length > 1000
    raise ArgumentError, 'reference_id must not contain quote or apostrophe characters' if reference_id.to_s.match?(/['"]/)
  end

  def check_opt_out!
    return unless AppleMessagesForBusiness::OptOutCheckerService.new(inbox: inbox, destination_id: destination_id).opted_out?

    raise "Contact #{destination_id} has opted out of invitation messages"
  end

  def handle_failure(response)
    Rails.logger.error "[AMB Invitation] ❌ Apple rejected invitation to #{destination_id}, templateId: #{template_id}, status: #{response.code}, body: #{response.body}"

    # 404 means Apple could not deliver at all - the caller (campaign service) must fall back to
    # another channel. Surface this distinctly instead of raising a generic error.
    if response.code == 404
      return { success: false, error: 'Apple MSP could not deliver invitation (404)',
               error_code: 'UNDELIVERABLE_FALLBACK_REQUIRED' }
    end

    # 410 for invitations means the message-type header was missing/invalid - a bug in our own
    # request building (that header is hardcoded below), not a user opt-out signal.
    Rails.logger.error '[AMB Invitation] Received 410 - check message-type header is being sent correctly' if response.code == 410

    raise "Apple MSP rejected invitation: HTTP #{response.code} — #{response.body}"
  end

  # rubocop:disable Metrics/MethodLength
  def build_payload(message_id)
    {
      'v' => 1,
      'id' => message_id,
      'sourceId' => inbox.channel.msp_id,
      'destinationId' => destination_id,
      'interactiveData' => {
        'bid' => 'com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension',
        'data' => {
          'version' => '1.0',
          # Always internally generated (never caller-supplied) - already a valid UUID, so no
          # extra validation is needed here unlike SendMessageService's caller-overridable field.
          'requestIdentifier' => SecureRandom.uuid,
          'notification' => AppleMessagesForBusiness::CaseTransformer.to_apple_format({
                                                                                        'template_id' => template_id,
                                                                                        'locale' => locale || 'en-us',
                                                                                        'reference_id' => reference_id,
                                                                                        'parameters' => filtered_parameters
                                                                                      })
        },
        'useLiveLayout' => true
      },
      'type' => 'interactive'
    }
  end
  # rubocop:enable Metrics/MethodLength

  def filtered_parameters
    return parameters unless template_id.to_s.downcase.include?('noimage')

    parameters.except('brand_logo', :brand_logo)
  end

  def send_to_apple(payload, message_id)
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{inbox.channel.generate_jwt_token}",
      'id' => message_id,
      'Source-Id' => inbox.channel.business_id,
      'Destination-Id' => destination_id,
      'message-type' => 'notification'
    }

    HTTParty.post(
      "#{AMB_SERVER}/message",
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end
end
