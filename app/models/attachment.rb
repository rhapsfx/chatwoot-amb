# == Schema Information
#
# Table name: attachments
#
#  id                   :integer          not null, primary key
#  coordinates_lat      :float            default(0.0)
#  coordinates_long     :float            default(0.0)
#  encrypted            :boolean          default(FALSE)
#  encryption_algorithm :string
#  encryption_key       :text
#  extension            :string
#  external_url         :string
#  fallback_title       :string
#  file_hash_value      :string
#  file_type            :integer          default("image")
#  meta                 :jsonb
#  storage_key_value    :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :integer          not null
#  message_id           :integer          not null
#
# Indexes
#
#  index_attachments_on_account_id         (account_id)
#  index_attachments_on_encrypted          (encrypted)
#  index_attachments_on_file_hash_value    (file_hash_value)
#  index_attachments_on_message_id         (message_id)
#  index_attachments_on_storage_key_value  (storage_key_value) UNIQUE
#

class Attachment < ApplicationRecord
  include Rails.application.routes.url_helpers

  ACCEPTABLE_FILE_TYPES = %w[
    text/csv text/plain text/rtf
    application/json application/pdf
    application/zip application/x-7z-compressed application/vnd.rar application/x-tar
    application/msword application/vnd.ms-excel application/vnd.ms-powerpoint application/rtf
    application/vnd.oasis.opendocument.text
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    model/vnd.usdz+zip
    application/vnd.usdz+zip
  ].freeze
  belongs_to :account
  belongs_to :message
  has_one_attached :file
  before_save :set_extension
  validate :acceptable_file
  validates :external_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  enum file_type: { :image => 0, :audio => 1, :video => 2, :file => 3, :location => 4, :fallback => 5, :share => 6, :story_mention => 7,
                    :contact => 8, :ig_reel => 9, :ig_post => 10, :ig_story => 11, :embed => 12 }

  # Encryption support for Apple Messages for Business
  def encrypted?
    return false unless respond_to?(:encryption_key) && respond_to?(:encrypted)

    encrypted == true && encryption_key.present?
  end

  def file_hash
    return nil unless respond_to?(:file_hash_value)

    file_hash_value
  end

  def storage_key
    return nil unless respond_to?(:storage_key_value)

    storage_key_value
  end

  def push_event_data
    return unless file_type

    base_data.merge(metadata_for_file_type)
  end

  # NOTE: the URl returned does a 301 redirect to the actual file
  def file_url
    @file_url ||= Rails.cache.fetch("attachment_file_url_#{id}_#{updated_at.to_i}", expires_in: 5.minutes) do
      generate_file_url
    end
  end

  # NOTE: for External services use this methods since redirect doesn't work effectively in a lot of cases
  def download_url
    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    file.attached? ? file.blob.url : ''
  end

  def thumb_url
    @thumb_url ||= Rails.cache.fetch("attachment_thumb_url_#{id}_#{updated_at.to_i}", expires_in: 5.minutes) do
      generate_thumb_url
    end
  end

  def with_attached_file?
    [:image, :audio, :video, :file].include?(file_type.to_sym)
  end

  private

  def with_custom_host
    original_host = Rails.application.routes.default_url_options[:host]
    original_protocol = Rails.application.routes.default_url_options[:protocol]

    Rails.logger.debug { "[Attachment] Entering with_custom_host block. Original host: #{original_host}" }
    custom_host = ENV['FRONTEND_URL'] || detect_active_public_url || 'localhost:10750'
    Rails.logger.debug { "[Attachment] Using custom host: #{custom_host}. Setting it for URL generation." }
    Rails.application.routes.default_url_options[:host] = custom_host
    Rails.application.routes.default_url_options[:protocol] = 'https'

    result = yield

    Rails.logger.debug { "[Attachment] Restoring original host: #{original_host}" }
    Rails.application.routes.default_url_options[:host] = original_host
    Rails.application.routes.default_url_options[:protocol] = original_protocol

    result
  end

  def generate_attachment_token(attachment_id)
    secret = Rails.application.secret_key_base
    Digest::SHA256.hexdigest("#{attachment_id}-#{secret}")[0..15]
  end

  def generate_file_url
    return '' unless file.attached?

    Rails.logger.debug { "[Attachment] Generating file_url for attachment ID: #{id}" }

    if apple_messages_channel?
      Rails.logger.debug '[Attachment] AMB channel detected. Using custom URL generator with domain.'
      token = generate_attachment_token(id)
      url = with_custom_host { Rails.application.routes.url_helpers.apple_messages_for_business_attachment_url(id, token: token) }
      Rails.logger.debug { "[Attachment] Generated AMB custom domain URL: #{url}" }
      url
    else
      Rails.logger.debug '[Attachment] Using standard url_for helper.'
      url = url_for(file)
      Rails.logger.debug { "[Attachment] Generated standard URL: #{url}" }
      url
    end
  end

  def generate_thumb_url
    return '' unless file.attached? && image?

    Rails.logger.debug { "[Attachment] Generating thumb_url for attachment ID: #{id}" }
    begin
      if apple_messages_channel?
        Rails.logger.debug '[Attachment] AMB channel detected for thumb. Using custom URL generator with domain.'
        token = generate_attachment_token(id)
        url = with_custom_host { Rails.application.routes.url_helpers.apple_messages_for_business_attachment_url(id, token: token) }
        Rails.logger.debug { "[Attachment] Generated AMB custom domain thumb URL: #{url}" }
        url
      else
        Rails.logger.debug '[Attachment] Using standard url_for helper for thumb.'
        url = url_for(file.representation(resize_to_fill: [250, nil]))
        Rails.logger.debug { "[Attachment] Generated standard thumb URL: #{url}" }
        url
      end
    rescue ActiveStorage::UnrepresentableError => e
      Rails.logger.warn "[Attachment] Unrepresentable image attachment: #{id} (#{file.filename}) - #{e.message}"
      ''
    end
  end

  def apple_messages_channel?
    @is_apple_messages ||= message&.inbox&.channel_type == 'Channel::AppleMessagesForBusiness'
  end

  def metadata_for_file_type
    case file_type.to_sym
    when :location
      location_metadata
    when :fallback
      fallback_data
    when :contact
      contact_metadata
    when :audio
      audio_metadata
    when :embed
      embed_data
    else
      file.attached? ? file_metadata : { data_url: external_url, thumb_url: '' }
    end
  end

  def embed_data
    {
      data_url: external_url
    }
  end

  def audio_metadata
    audio_file_data = base_data.merge(file_metadata)
    audio_file_data.merge(
      {
        transcribed_text: meta&.[]('transcribed_text') || ''
      }
    )
  end

  def file_metadata
    metadata = {
      extension: extension,
      content_type: file.content_type,
      data_url: file_url,
      thumb_url: thumb_url,
      file_size: file.byte_size,
      file_name: file.filename.to_s,
      width: file.metadata[:width],
      height: file.metadata[:height]
    }

    metadata[:data_url] = metadata[:thumb_url] = external_url if instagram_incoming_message?
    metadata
  end

  def location_metadata
    {
      coordinates_lat: coordinates_lat,
      coordinates_long: coordinates_long,
      fallback_title: fallback_title,
      data_url: external_url
    }
  end

  def fallback_data
    {
      fallback_title: fallback_title,
      data_url: external_url
    }
  end

  def base_data
    {
      id: id,
      message_id: message_id,
      file_type: file_type,
      account_id: account_id
    }
  end

  def contact_metadata
    {
      fallback_title: fallback_title,
      meta: meta || {}
    }
  end

  def instagram_incoming_message?
    return false unless message.incoming?

    return true if message.inbox.instagram_direct?

    message.inbox.instagram? && message.conversation&.additional_attributes&.dig('type') == 'instagram_direct_message'
  end

  def set_extension
    return unless file.attached?
    return if extension.present?

    self.extension = File.extname(file.filename.to_s).delete_prefix('.').presence
  end

  def should_validate_file?
    return unless file.attached?
    # we are only limiting attachment types in case of website widget
    return unless message.inbox.channel_type == 'Channel::WebWidget'

    true
  end

  def acceptable_file
    return unless should_validate_file?

    validate_file_size(file.byte_size)
    validate_file_content_type(file.content_type)
  end

  def validate_file_content_type(file_content_type)
    is_usdz = file.filename.to_s.downcase.end_with?('.usdz')

    errors.add(:file, 'type not supported') unless media_file?(file_content_type) || ACCEPTABLE_FILE_TYPES.include?(file_content_type) || is_usdz
  end

  def validate_file_size(byte_size)
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0

    # Override for Apple Messages for Business - 100 MB per Apple MSP REST API v4.1.5
    limit_mb = 100 if message.inbox.channel_type == 'Channel::AppleMessagesForBusiness'

    errors.add(:file, 'size is too big') if byte_size > limit_mb.megabytes
  end

  def media_file?(file_content_type)
    file_content_type.start_with?('image/', 'video/', 'audio/')
  end

  def detect_active_public_url
    Rails.cache.fetch('attachment_active_public_url', expires_in: 30.seconds) do
      begin
        tailscale_url_file = Rails.root.join('tmp/pids/tailscale_url.txt')
        if File.exist?(tailscale_url_file)
          tailscale_url = File.read(tailscale_url_file).strip
          return tailscale_url if tailscale_url.present?
        end

        require 'net/http'
        uri = URI('http://localhost:4040/api/tunnels')
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          require 'json'
          tunnels = JSON.parse(response.body)
          public_url = tunnels.dig('tunnels', 0, 'public_url')
          return public_url.sub(%r{^https?://}, '') if public_url&.include?('https')
        end
      rescue StandardError => e
        Rails.logger.debug { "[Attachment] Could not detect active public URL: #{e.message}" }
      end

      begin
        require 'socket'
        TCPSocket.new('localhost', 443).close
        return 'dev.rhaps.net'
      rescue Errno::ECONNREFUSED
        # Custom domain not available
      end

      nil
    end
  end
end

Attachment.include_mod_with('Concerns::Attachment')
