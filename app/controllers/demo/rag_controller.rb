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
end
