class Api::V1::Accounts::Inboxes::AppleListPickerImagesController < Api::V1::Accounts::BaseController
  include LogSanitizable

  before_action :fetch_inbox
  before_action :log_deprecation_warning
  # No authorization check needed - if user can access the inbox via fetch_inbox, they can manage images

  def index
    @images = @inbox.apple_list_picker_images.for_inbox(@inbox.id)
    Rails.logger.info "[AppleListPickerImages API] Returning #{@images.count} images for inbox #{@inbox.id}"
    render json: serialize_images(@images)
  rescue StandardError => e
    Rails.logger.error "[AppleListPickerImages API] Error loading images: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  def create
    @image = @inbox.apple_list_picker_images.new(image_params)
    @image.account_id = Current.account.id

    if params[:image_file].present?
      @image.image.attach(params[:image_file])
    elsif params[:image_data].present?
      # Handle base64 data
      decoded_data = Base64.strict_decode64(params[:image_data])
      filename = params[:filename] || "#{params[:identifier]}.jpg"
      content_type = params[:content_type] || 'image/jpeg'

      @image.image.attach(
        io: StringIO.new(decoded_data),
        filename: filename,
        content_type: content_type
      )
    end

    if @image.save
      render json: serialize_image(@image), status: :created
    else
      render json: { errors: @image.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @image = @inbox.apple_list_picker_images.find(params[:id])
    @image.destroy
    head :no_content
  end

  # POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/copy_from
  # Copy images from another inbox
  # Params: { source_inbox_id: 123, identifiers: ['0', '1', '2'] }
  def copy_from
    source_inbox_id = params[:source_inbox_id]
    identifiers = params[:identifiers] || []

    if source_inbox_id.blank?
      render json: { error: 'source_inbox_id is required' }, status: :bad_request
      return
    end

    if identifiers.empty?
      render json: { error: 'identifiers array is required' }, status: :bad_request
      return
    end

    Current.account.inboxes.find(source_inbox_id)
    results = { copied: [], skipped: [], errors: [] }

    identifiers.each do |identifier|
      # Find source image
      source_image = AppleListPickerImage.find_by(inbox_id: source_inbox_id, identifier: identifier)

      unless source_image&.image&.attached?
        results[:errors] << { identifier: identifier, error: 'Source image not found' }
        next
      end

      begin
        # Check if already exists in target inbox
        existing = AppleListPickerImage.find_by(inbox_id: @inbox.id, identifier: identifier)
        if existing
          results[:skipped] << { identifier: identifier, reason: 'Already exists in target inbox' }
          next
        end

        # Download and copy image
        image_data = source_image.image.download

        new_image = @inbox.apple_list_picker_images.new(
          account_id: Current.account.id,
          identifier: identifier,
          original_name: source_image.original_name,
          description: source_image.description
        )

        new_image.image.attach(
          io: StringIO.new(image_data),
          filename: source_image.image.filename.to_s,
          content_type: source_image.image.content_type
        )

        new_image.save!

        results[:copied] << serialize_image(new_image)
      rescue StandardError => e
        Rails.logger.error "[AppleListPickerImages] Copy failed for #{identifier}: #{e.message}"
        results[:errors] << { identifier: identifier, error: e.message }
      end
    end

    render json: results, status: :ok
  end

  # POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images/bulk_upload
  # Upload same image to multiple inboxes
  # Params: { inbox_ids: [4, 5], identifier: '0', image_data: 'base64...', filename: 'image.png' }
  def bulk_upload
    inbox_ids = params[:inbox_ids] || []
    identifier = params[:identifier]
    image_data_b64 = params[:image_data]
    filename = params[:filename] || "#{identifier}.jpg"
    content_type = params[:content_type] || 'image/jpeg'
    description = params[:description]
    original_name = params[:original_name]

    if inbox_ids.empty?
      render json: { error: 'inbox_ids array is required' }, status: :bad_request
      return
    end

    if identifier.blank?
      render json: { error: 'identifier is required' }, status: :bad_request
      return
    end

    if image_data_b64.blank?
      render json: { error: 'image_data (base64) is required' }, status: :bad_request
      return
    end

    begin
      decoded_data = Base64.strict_decode64(image_data_b64)
    rescue ArgumentError => e
      render json: { error: "Invalid base64 data: #{e.message}" }, status: :bad_request
      return
    end

    results = { uploaded: [], skipped: [], errors: [] }

    inbox_ids.each do |inbox_id|
      inbox = Current.account.inboxes.find(inbox_id)

      # Check if already exists
      existing = AppleListPickerImage.find_by(inbox_id: inbox_id, identifier: identifier)
      if existing
        results[:skipped] << { inboxId: inbox_id, inboxName: inbox.name, reason: 'Already exists' }
        next
      end

      # Create new image
      new_image = inbox.apple_list_picker_images.new(
        account_id: Current.account.id,
        identifier: identifier,
        original_name: original_name || filename,
        description: description
      )

      new_image.image.attach(
        io: StringIO.new(decoded_data),
        filename: filename,
        content_type: content_type
      )

      new_image.save!

      results[:uploaded] << {
        inboxId: inbox_id,
        inboxName: inbox.name,
        image: serialize_image(new_image)
      }
    rescue ActiveRecord::RecordNotFound
      results[:errors] << { inboxId: inbox_id, error: 'Inbox not found' }
    rescue StandardError => e
      Rails.logger.error "[AppleListPickerImages] Bulk upload failed for inbox #{inbox_id}: #{e.message}"
      results[:errors] << { inboxId: inbox_id, error: e.message }
    end

    render json: results, status: :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def log_deprecation_warning
    Rails.logger.warn(
      '[DEPRECATED] apple_list_picker_images endpoint used. ' \
      'Please migrate to apple_amb_images. ' \
      "Endpoint: #{action_name}, IP: #{request.remote_ip}, " \
      "Account: #{Current.account&.id}, Inbox: #{params[:inbox_id]}"
    )
  end

  def image_params
    params.permit(:identifier, :description, :original_name)
  end

  def serialize_images(images)
    images.map { |img| serialize_image(img) }
  end

  def serialize_image(image)
    {
      id: image.id,
      identifier: image.identifier,
      description: image.description,
      original_name: image.original_name,
      image_url: image.image_url,
      image_data_base64: nil, # Don't send base64 by default, only on demand
      created_at: image.created_at,
      updated_at: image.updated_at
    }
  end
end
