class Demo::RagController < ApplicationController
  def index
    embedding = Openai::EmbeddingsService.new.get_embedding(params[:query])
    responses = Response.active.nearest_neighbors(:embedding, embedding, distance: 'cosine').first(5)
    formatted_responses = responses.collect do |response|
      "question: #{response.question}\nanswer: #{response.answer}\n\n------"
    end.join("\n")

    # strip all * from formatted_responses
    formatted_responses = formatted_responses.delete('*')
    render json: { query: params[:query], response: formatted_responses }
  end

  def daily_meeting_url
    response = HTTParty.post(
      'https://api.daily.co/v1/rooms',
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('DAILY_API_KEY', '')}"
      },
      body: {
        'properties' => daily_room_props
      }.to_json
    )

    daily_meeting_url = JSON.parse(response.body)['url']
    make_bot_join_meeting(daily_meeting_url)
    render json: { daily_meeting_url: daily_meeting_url }
  end

  private

  def make_bot_join_meeting(daily_meeting_url)
    HTTParty.post(
      ENV.fetch('ROBIN_BOT_LAMBDA_URL', '').to_s,
      body: {
        'url' => daily_meeting_url.to_s
      }.to_json,
      timeout: 1.second
    )
  rescue Net::ReadTimeout
    # we don't want to wait for the response
    Rails.logger.error('HTTParty request timed out')
  rescue StandardError => e
    Rails.logger.error("HTTParty request failed with error: #{e.message}")
  end

  def daily_room_props
    {
      'exp' => Time.now.to_i + (60 * 5), # 1 hour
      'enable_chat' => false,
      'enable_emoji_reactions' => false,
      'eject_at_room_exp' => false,
      'enable_prejoin_ui' => false,
      'start_video_off' => true # Important for the bot to be able to join headlessly
    }
  end
end
