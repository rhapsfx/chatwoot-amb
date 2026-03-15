# frozen_string_literal: true

# ImageFetchService - Three-Tier Image Fallback for Apple Messages
#
# IMPLEMENTATION STATUS: Phase 2 (Service Integration) - IN PROGRESS
# This service is now being integrated into production services.
# See docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md for complete integration plan.
#
# Current Integration Status:
# - SendListPickerService: ✅ INTEGRATED (using ImageFetchService)
# - SendTimePickerService: ✅ INTEGRATED (using ImageFetchService)
# - FormService: ✅ INTEGRATED (using ImageFetchService)
# - AcousticHouseBotService: ✅ INTEGRATED (using ImageFetchService)
#
# CASE CONVENTION & CaseTransformer:
# This service operates at the storage layer and uses snake_case identifiers (Rails convention).
# CaseTransformer is NOT used here because:
# - Image identifiers are stored in snake_case in the database
# - Identifiers are queried in snake_case
# - CaseTransformer is applied at the Apple MSP boundary (in Send*Service classes)
#   when building interactive message payloads for transmission to Apple
#
# Example Flow:
#   Frontend (camelCase) → API Controller (auto-normalizes to snake_case)
#   → Database (stores snake_case) → ImageFetchService (queries snake_case)
#   → SendListPickerService (uses CaseTransformer to convert to camelCase for Apple MSP)
#
# Three-Tier Fallback Hierarchy:
# 1. Inbox-specific images (AppleListPickerImage) - Highest priority
# 2. Account-wide shared images (SharedAppleImage) - Fallback
# 3. Embedded template images (content_attributes['images']) - Final fallback
#
# Usage (when Phase 2 integration is complete):
#   service = AppleMessagesForBusiness::ImageFetchService.new(
#     account_id: message.account_id,
#     inbox_id: message.inbox_id,
#     embedded_images: content_attributes['images']
#   )
#   images = service.fetch_and_encode(['messages_png', 'store_logo'])
#
class AppleMessagesForBusiness::ImageFetchService
  include AppleMessagesForBusiness::Concerns::Utf8Logging

  def initialize(account_id:, inbox_id:, embedded_images: [])
    @account_id = account_id
    @inbox_id = inbox_id
    @embedded_images = embedded_images || []
  end

  def fetch_and_encode(identifiers)
    return [] if identifiers.blank?

    Rails.logger.info "[ImageFetch] Looking for #{identifiers.count} images"
    Rails.logger.info "[ImageFetch] Account: #{@account_id}, Inbox: #{@inbox_id}"

    result = []

    identifiers.each do |identifier|
      image = fetch_single_image(identifier)
      result << image if image.present?
    end

    Rails.logger.info "[ImageFetch] Found #{result.count}/#{identifiers.count} images"
    result
  end

  private

  def fetch_single_image(identifier)
    # TIER 1: Check inbox-specific images first (highest priority)
    inbox_image = fetch_from_inbox(identifier)
    return inbox_image if inbox_image.present?

    # TIER 2: Check shared account-wide images
    shared_image = fetch_from_shared(identifier)
    return shared_image if shared_image.present?

    # TIER 3: Check embedded images
    embedded_image = fetch_from_embedded(identifier)
    return embedded_image if embedded_image.present?

    Rails.logger.warn "[ImageFetch] ⚠️  Image not found: #{identifier}"
    nil
  end

  def fetch_from_inbox(identifier)
    picker_image = AppleListPickerImage
                   .where(inbox_id: @inbox_id, identifier: identifier)
                   .includes(image_attachment: :blob)
                   .first

    return nil unless picker_image&.image&.attached?

    Rails.logger.info "[ImageFetch] ✅ Found in inbox #{@inbox_id}: #{identifier}"

    {
      identifier: identifier,
      data: Base64.strict_encode64(picker_image.image.download),
      description: picker_image.description || identifier,
      source: 'inbox'
    }
  rescue StandardError => e
    Rails.logger.error "[ImageFetch] Error fetching inbox image #{identifier}: #{e.message}"
    nil
  end

  def fetch_from_shared(identifier)
    shared_image = SharedAppleImage
                   .where(account_id: @account_id, identifier: identifier)
                   .includes(image_attachment: :blob)
                   .first

    return nil unless shared_image&.image&.attached?

    Rails.logger.info "[ImageFetch] ✅ Found in shared (#{shared_image.image_type}): #{identifier}"

    {
      identifier: identifier,
      data: Base64.strict_encode64(shared_image.image.download),
      description: shared_image.description || identifier,
      source: "shared_#{shared_image.image_type}"
    }
  rescue StandardError => e
    Rails.logger.error "[ImageFetch] Error fetching shared image #{identifier}: #{e.message}"
    nil
  end

  def fetch_from_embedded(identifier)
    embedded = @embedded_images.find do |img|
      next false unless img.is_a?(Hash)

      img['identifier'] == identifier || img[:identifier] == identifier
    end

    embedded_data = embedded&.dig('data') || embedded&.dig(:data)
    return nil if embedded.blank? || embedded_data.blank?

    Rails.logger.info "[ImageFetch] ✅ Found in embedded: #{identifier}"

    {
      identifier: identifier,
      data: embedded_data, # Already base64
      description: embedded['description'] || embedded[:description] || identifier,
      source: 'embedded'
    }
  rescue StandardError => e
    Rails.logger.error "[ImageFetch] Error fetching embedded image #{identifier}: #{e.message}"
    nil
  end
end
