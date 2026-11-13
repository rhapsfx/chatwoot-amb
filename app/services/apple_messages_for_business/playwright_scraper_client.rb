# frozen_string_literal: true

# HTTP client for the Playwright stealth scraper microservice.
#
# The service runs as a separate Node.js process (see services/playwright-scraper/).
# It uses playwright-extra + puppeteer-extra-plugin-stealth to bypass bot-detection
# systems (Akamai, Cloudflare, etc.) that block our plain HTTParty scraper.
#
# Returns nil on any failure so the caller can fall back to the HTTParty path.
module AppleMessagesForBusiness
  class PlaywrightScraperClient
    SERVICE_URL = ENV.fetch('PLAYWRIGHT_SCRAPER_URL', 'http://localhost:3001')
    TIMEOUT_SECONDS = 25

    def self.fetch(url)
      return nil if url.blank?

      Rails.logger.info "[PlaywrightScraper] Requesting scrape for: #{url}"

      response = HTTParty.post(
        "#{SERVICE_URL}/scrape",
        body: { url: url }.to_json,
        headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
        timeout: TIMEOUT_SECONDS
      )

      unless response.success?
        Rails.logger.warn "[PlaywrightScraper] Service returned #{response.code} for #{url}"
        return nil
      end

      data = response.parsed_response
      unless data.is_a?(Hash) && data['success']
        Rails.logger.warn "[PlaywrightScraper] Service reported failure: #{data['error']}"
        return nil
      end

      Rails.logger.info "[PlaywrightScraper] Success — title: #{data['title']&.truncate(60)}"
      data.transform_keys(&:to_sym)
    rescue StandardError => e
      Rails.logger.warn "[PlaywrightScraper] Unavailable (#{e.class}): #{e.message}"
      nil
    end
  end
end
