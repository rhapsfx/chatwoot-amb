class Api::V1::Accounts::SharedAppleImagesController < Api::V1::Accounts::BaseController
  include LogSanitizable

  before_action :check_authorization
  before_action :set_shared_image, only: [:show, :update, :destroy, :upload, :remove_image]
  before_action :set_current_page, only: [:index, :system_images, :branding_images, :template_images]

  RESULTS_PER_PAGE = 25

  # GET /api/v1/accounts/:account_id/shared_apple_images
  def index
    @images = fetch_images(Current.account.shared_apple_images)
    @images_count = @images.total_count
    render json: {
      data: serialize_images(@images),
      meta: pagination_meta
    }
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/system_images
  def system_images
    @images = fetch_images(Current.account.shared_apple_images.system_images)
    @images_count = @images.total_count
    render json: {
      data: serialize_images(@images),
      meta: pagination_meta
    }
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/branding_images
  def branding_images
    @images = fetch_images(Current.account.shared_apple_images.branding_images)
    @images_count = @images.total_count
    render json: {
      data: serialize_images(@images),
      meta: pagination_meta
    }
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/template_images
  def template_images
    @images = fetch_images(Current.account.shared_apple_images.template_images)
    @images_count = @images.total_count
    render json: {
      data: serialize_images(@images),
      meta: pagination_meta
    }
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/:id
  def show
    render json: serialize_image(@shared_image, include_base64: true)
  end

  # POST /api/v1/accounts/:account_id/shared_apple_images
  def create
    @shared_image = Current.account.shared_apple_images.new(shared_image_params)

    attach_image if image_provided?

    if @shared_image.save
      render json: serialize_image(@shared_image), status: :created
    else
      render json: { errors: @shared_image.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[SharedAppleImages] Create failed: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # PATCH/PUT /api/v1/accounts/:account_id/shared_apple_images/:id
  def update
    if @shared_image.update(shared_image_params)
      render json: serialize_image(@shared_image)
    else
      render json: { errors: @shared_image.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[SharedAppleImages] Update failed: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # DELETE /api/v1/accounts/:account_id/shared_apple_images/:id
  def destroy
    @shared_image.destroy
    head :no_content
  rescue StandardError => e
    Rails.logger.error "[SharedAppleImages] Destroy failed: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # POST /api/v1/accounts/:account_id/shared_apple_images/:id/upload
  def upload
    unless image_provided?
      render json: { error: 'No image provided' }, status: :bad_request
      return
    end

    attach_image

    if @shared_image.save
      render json: serialize_image(@shared_image)
    else
      render json: { errors: @shared_image.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[SharedAppleImages] Upload failed: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # DELETE /api/v1/accounts/:account_id/shared_apple_images/:id/remove_image
  def remove_image
    @shared_image.image.purge if @shared_image.image.attached?
    render json: serialize_image(@shared_image)
  rescue StandardError => e
    Rails.logger.error "[SharedAppleImages] Remove image failed: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def set_shared_image
    @shared_image = Current.account.shared_apple_images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Image not found' }, status: :not_found
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_images(scope)
    scope.order(created_at: :desc)
         .page(@current_page)
         .per(params[:per_page] || RESULTS_PER_PAGE)
  end

  def shared_image_params
    params.require(:shared_apple_image).permit(
      :identifier,
      :image_type,
      :description,
      :original_name,
      metadata: {}
    )
  end

  def image_provided?
    params[:image_file].present? || params[:image_data].present?
  end

  def attach_image
    if params[:image_file].present?
      @shared_image.image.attach(params[:image_file])
    elsif params[:image_data].present?
      attach_base64_image
    end
  end

  def attach_base64_image
    decoded_data = Base64.strict_decode64(params[:image_data])
    filename = params[:filename] || "#{params[:identifier] || 'image'}.jpg"
    content_type = params[:content_type] || 'image/jpeg'

    @shared_image.image.attach(
      io: StringIO.new(decoded_data),
      filename: filename,
      content_type: content_type
    )
  rescue ArgumentError => e
    raise "Invalid base64 data: #{e.message}"
  end

  def serialize_images(images)
    images.map { |img| serialize_image(img) }
  end

  def serialize_image(image, include_base64: false)
    result = {
      id: image.id,
      identifier: image.identifier,
      image_type: image.image_type,
      description: image.description,
      original_name: image.original_name,
      metadata: image.metadata,
      image_url: image.image_url,
      created_at: image.created_at,
      updated_at: image.updated_at
    }

    result[:image_data_base64] = image.image_data_base64 if include_base64 && image.image.attached?

    result
  end

  def pagination_meta
    {
      current_page: @current_page.to_i,
      total_pages: @images.total_pages,
      total_count: @images_count,
      per_page: (params[:per_page] || RESULTS_PER_PAGE).to_i
    }
  end

  def check_authorization
    authorize :shared_apple_image
  end
end
