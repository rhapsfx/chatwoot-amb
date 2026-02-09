class Api::V1::Accounts::AppleMessagesController < Api::V1::Accounts::BaseController
  def parse_url
    url = params[:url]

    if url.blank?
      render json: { error: 'URL is required' }, status: :bad_request
      return
    end

    begin
      parser_service = AppleMessagesForBusiness::OpenGraphParserService.new(url)
      result = parser_service.parse

      if result[:success]
        render json: {
          url: result[:url],
          title: result[:title],
          description: result[:description],
          image_url: result[:image_url],
          video_url: result[:video_url],
          video_mime_type: result[:video_mime_type],
          favicon_url: result[:favicon_url],
          site_name: result[:site_name]
        }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Apple Messages URL parsing failed: #{e.message}"
      render json: { error: 'Failed to parse URL' }, status: :internal_server_error
    end
  end

  def app_metadata
    bundle_id = params[:bundle_id]

    if bundle_id.blank?
      render json: { error: 'Bundle ID is required' }, status: :bad_request
      return
    end

    begin
      Rails.logger.info "AppleMessagesController: Fetching metadata for bundle_id: #{bundle_id}"
      app_data = AppleAppMetadata.fetch_and_cache(bundle_id)

      if app_data
        Rails.logger.info "AppleMessagesController: Found app data for #{app_data.app_name}"
        render json: {
          bundle_id: app_data.bundle_id,
          app_name: app_data.app_name,
          developer_name: app_data.developer_name,
          app_icon_url: app_data.app_icon_url,
          app_store_url: app_data.app_store_url,
          description: app_data.description,
          price: app_data.price
        }
      else
        Rails.logger.warn "AppleMessagesController: App not found for bundle_id: #{bundle_id}"
        render json: { error: 'App not found in iTunes Store' }, status: :not_found
      end
    rescue StandardError => e
      Rails.logger.error "AppleMessagesController: Failed to fetch app metadata for #{bundle_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Failed to fetch app metadata' }, status: :internal_server_error
    end
  end
end
