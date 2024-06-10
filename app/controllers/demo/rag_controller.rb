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
    # generate a daily meeting url

    room_props = {
      'exp' => Time.now.to_i + (60 * 5), # 1 hour
      'enable_chat' => false,
      'enable_emoji_reactions' => false,
      'eject_at_room_exp' => false,
      'enable_prejoin_ui' => false,
      'start_video_off' => true # Important for the bot to be able to join headlessly
    }

    response = HTTParty.post(
      'https://api.daily.co/v1/rooms',
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('DAILY_API_KEY', '')}"
      },
      body: {
        'properties' => room_props
      }.to_json
    )

    render json: { daily_meeting_url: JSON.parse(response.body)['url'] }
  end
end
