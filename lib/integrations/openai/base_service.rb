class Integrations::OpenaiBaseService
  # gpt-4o-mini supports 128,000 tokens
  # 1 token is approx 4 characters
  # sticking with 120000 to be safe
  # 120000 * 4 = 480,000 characters (rounding off downwards to 400,000 to be safe)
  TOKEN_LIMIT = 400_000
  GPT_MODEL = Llm::Config::DEFAULT_MODEL

  ALLOWED_EVENT_NAMES = %w[rephrase summarize reply_suggestion fix_spelling_grammar shorten expand make_friendly make_formal simplify].freeze

  pattr_initialize [:hook!, :event!]

  private

  def conversation
    @conversation ||= hook.account.conversations.find_by(display_id: event['data']['conversation_display_id'])
  end

  def api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence || 'https://api.openai.com/'
    endpoint = endpoint.chomp('/')
    "#{endpoint}/v1"
  end

  def make_api_call(body)
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{hook.settings['api_key']}"
    }

    Rails.logger.info("OpenAI API request: #{body}")
    response = HTTParty.post("#{api_base}/chat/completions", headers: headers, body: body)
    Rails.logger.info("OpenAI API response: #{response.body}")

    return { error: response.parsed_response, error_code: response.code } unless response.success?

    choices = JSON.parse(response.body)['choices']

    return { message: choices.first['message']['content'] } if choices.present?

    { message: nil }
  end
end
