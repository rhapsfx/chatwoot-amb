# frozen_string_literal: true

module AppleMessagesForBusiness
  module Concerns
    # URL recognition for the Construct Payload API's supported URL types (spec v4.2.9).
    #
    # This only recognizes *which* host a URL belongs to — it does not extract place/song/album
    # details, since Construct Payload's whole point is that Apple's endpoint resolves that
    # content server-side. This is deliberately narrower than
    # OpenGraphParserService's Apple Maps helpers, which extract full location parameters for the
    # older, fully-local manual rich-link flow (a different code path with no server-side
    # resolution) — that richer parsing logic is not duplicated here.
    module ConstructPayloadUrlDetection
      private

      def apple_maps_url?(url)
        url.to_s.match?(%r{\Ahttps?://(?:www\.)?maps\.apple(?:\.com)?/}i)
      end

      def apple_music_url?(url)
        url.to_s.match?(%r{\Ahttps?://(?:www\.)?music\.apple\.com/}i)
      end
    end
  end
end
