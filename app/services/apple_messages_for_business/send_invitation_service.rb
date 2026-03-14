class AppleMessagesForBusiness::SendInvitationService
  AMB_SERVER = 'https://mspgw.push.apple.com/v1'.freeze

  pattr_initialize [:inbox!, :destination_id!, :template_id!, :reference_id!, :parameters!, :locale]

  def perform
    check_opt_out!
    message_id = SecureRandom.uuid
    payload = build_payload(message_id)
    response = send_to_apple(payload, message_id)
    if response.success?
      Rails.logger.info "[AMB Invitation] ✅ Sent to #{destination_id}, templateId: #{template_id}, status: #{response.code}"
    else
      Rails.logger.error "[AMB Invitation] ❌ Apple rejected invitation to #{destination_id}, templateId: #{template_id}, status: #{response.code}, body: #{response.body}"
      raise "Apple MSP rejected invitation: HTTP #{response.code} — #{response.body}"
    end
    { success: true, response: response }
  rescue StandardError => e
    Rails.logger.error "[AMB Invitation] Failed for #{destination_id}: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def check_opt_out!
    return unless AppleInvitationOptOut.opted_out?(phone_number: destination_id, inbox_id: inbox.id)

    raise "Contact #{destination_id} has opted out of invitation messages"
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
          'requestIdentifier' => SecureRandom.uuid,
          'notification' => AppleMessagesForBusiness::CaseTransformer.to_apple_format({
                                                                                        'template_id' => template_id,
                                                                                        'locale' => locale || 'en-us',
                                                                                        'reference_id' => reference_id,
                                                                                        'parameters' => parameters
                                                                                      })
        },
        'useLiveLayout' => true
      },
      'type' => 'interactive'
    }
  end
  # rubocop:enable Metrics/MethodLength

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
