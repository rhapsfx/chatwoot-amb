# SharedAppleImages Controller - Implementation Reference

This document provides ready-to-use implementation code for the SharedAppleImages API controller.

## File Location
`app/controllers/api/v1/accounts/shared_apple_images_controller.rb`

## Controller Implementation

```ruby
# frozen_string_literal: true

class Api::V1::Accounts::SharedAppleImagesController < Api::V1::Accounts::BaseController
  before_action :fetch_image, only: [:show, :update, :destroy, :upload, :remove_image]
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/shared_apple_images
  # List all shared images for the account with pagination
  def index
    render json: index_query
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/system_images
  # List all system type images
  def system_images
    render json: index_query(image_type: 'system')
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/branding_images
  # List all branding type images
  def branding_images
    render json: index_query(image_type: 'branding')
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/template_images
  # List all template type images
  def template_images
    render json: index_query(image_type: 'template')
  end

  # GET /api/v1/accounts/:account_id/shared_apple_images/:id
  # Show a specific shared image
  def show
    render json: { shared_apple_image: serialize_image(@image) }
  end

  # POST /api/v1/accounts/:account_id/shared_apple_images
  # Create a new shared image
  def create
    @image = Current.account.shared_apple_images.new(image_params)

    if @image.save
      render json: { shared_apple_image: serialize_image(@image) }, status: :created
    else
      render json: { errors: @image.errors.messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/accounts/:account_id/shared_apple_images/:id
  # Update a shared image
  def update
    if @image.update(image_params)
      render json: { shared_apple_image: serialize_image(@image) }
    else
      render json: { errors: @image.errors.messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/accounts/:account_id/shared_apple_images/:id
  # Delete a shared image
  def destroy
    @image.destroy
    head :no_content
  end

  # POST /api/v1/accounts/:account_id/shared_apple_images/:id/upload
  # Upload or replace the image attachment
  def upload
    if params[:image].blank?
      render json: { errors: { image: ['must be present'] } }, status: :unprocessable_entity
      return
    end

    # Remove existing attachment if present
    @image.image.purge if @image.image.attached?

    # Attach new image
    @image.image.attach(params[:image])
    @image.touch # Update updated_at timestamp

    render json: { shared_apple_image: serialize_image(@image) }
  rescue StandardError => e
    render json: { errors: { image: [e.message] } }, status: :unprocessable_entity
  end

  # DELETE /api/v1/accounts/:account_id/shared_apple_images/:id/remove_image
  # Remove the image attachment but keep the record
  def remove_image
    @image.image.purge if @image.image.attached?
    @image.touch # Update updated_at timestamp

    render json: { shared_apple_image: serialize_image(@image, include_url: false) }
  end

  private

  # Fetch the image resource, returning 404 if not found
  def fetch_image
    @image = Current.account.shared_apple_images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not found' }, status: :not_found
  end

  # Strong parameters for image creation and updates
  def image_params
    params.permit(:identifier, :image_type, :description, :original_name, :image, metadata: {})
  end

  # Serialize a single image to JSON
  # @param image [SharedAppleImage] The image to serialize
  # @param include_url [Boolean] Whether to include the attachment URL (default: true)
  def serialize_image(image, include_url: true)
    data = {
      id: image.id,
      identifier: image.identifier,
      image_type: image.image_type,
      description: image.description,
      original_name: image.original_name,
      account_id: image.account_id,
      metadata: image.metadata || {},
      created_at: image.created_at,
      updated_at: image.updated_at
    }

    # Add image URL if attachment exists and include_url is true
    if include_url && image.image.attached?
      data[:image_url] = rails_blob_url(image.image, only_path: false)
    end

    data
  end

  # Serialize an array of images
  def serialize_images(images)
    images.map { |img| serialize_image(img) }
  end

  # Build paginated index query results
  # @param image_type [String, nil] Optional filter by image type
  def index_query(image_type: nil)
    images = Current.account.shared_apple_images.order(created_at: :desc)
    images = images.where(image_type: image_type) if image_type.present?

    # Pagination parameters with defaults and limits
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min

    # Calculate offset and paginate
    paginated = images.offset((page - 1) * per_page).limit(per_page)

    {
      shared_apple_images: serialize_images(paginated),
      total: images.count,
      page: page,
      per_page: per_page
    }
  end
end
```

## Integration with routes.rb

Verify that `config/routes.rb` contains:

```ruby
namespace :api do
  namespace :v1 do
    resources :accounts, only: [] do
      resources :shared_apple_images, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :upload
          delete :remove_image
        end
        collection do
          get :system_images
          get :branding_images
          get :template_images
        end
      end
    end
  end
end
```

## Policy File (Optional but Recommended)

Create `app/policies/shared_apple_image_policy.rb` if you need fine-grained authorization:

```ruby
# frozen_string_literal: true

class SharedAppleImagePolicy < ApplicationPolicy
  def index?
    account_user?
  end

  def show?
    account_user? && record.account_id == user.account_id
  end

  def create?
    account_user?
  end

  def update?
    account_user? && record.account_id == user.account_id
  end

  def destroy?
    account_user? && record.account_id == user.account_id
  end

  def upload?
    account_user? && record.account_id == user.account_id
  end

  def remove_image?
    account_user? && record.account_id == user.account_id
  end

  private

  def account_user?
    user.account_id == Current.account.id
  end
end
```

## Example API Requests

### List all images
```bash
curl -X GET "http://localhost:3000/api/v1/accounts/1/shared_apple_images?page=1&per_page=20" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Get system images only
```bash
curl -X GET "http://localhost:3000/api/v1/accounts/1/shared_apple_images/system_images" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Get single image
```bash
curl -X GET "http://localhost:3000/api/v1/accounts/1/shared_apple_images/1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Create image with metadata
```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/shared_apple_images" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my_system_icon",
    "image_type": "system",
    "description": "Main system icon",
    "original_name": "icon.png",
    "metadata": {
      "width": 512,
      "height": 512,
      "format": "png"
    }
  }'
```

### Create image with file upload
```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/shared_apple_images" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "identifier=my_logo" \
  -F "image_type=branding" \
  -F "description=Company logo" \
  -F "image=@/path/to/logo.png"
```

### Update image metadata
```bash
curl -X PUT "http://localhost:3000/api/v1/accounts/1/shared_apple_images/1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Updated description",
    "metadata": {
      "width": 1024,
      "height": 1024
    }
  }'
```

### Upload new image file
```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/shared_apple_images/1/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "image=@/path/to/new_image.png"
```

### Remove image attachment
```bash
curl -X DELETE "http://localhost:3000/api/v1/accounts/1/shared_apple_images/1/remove_image" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Delete image completely
```bash
curl -X DELETE "http://localhost:3000/api/v1/accounts/1/shared_apple_images/1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

## Response Examples

### Success - List Response (200 OK)
```json
{
  "shared_apple_images": [
    {
      "id": 1,
      "identifier": "apple_img_1",
      "image_type": "system",
      "description": "Test image description",
      "original_name": "test_image.png",
      "account_id": 1,
      "image_url": "https://example.com/rails/active_storage/blobs/...",
      "metadata": {
        "width": 400,
        "height": 400
      },
      "created_at": "2025-11-19T10:30:00Z",
      "updated_at": "2025-11-19T10:30:00Z"
    }
  ],
  "total": 25,
  "page": 1,
  "per_page": 20
}
```

### Success - Single Image (200 OK)
```json
{
  "shared_apple_image": {
    "id": 1,
    "identifier": "apple_img_1",
    "image_type": "system",
    "description": "Test image description",
    "original_name": "test_image.png",
    "account_id": 1,
    "image_url": "https://example.com/rails/active_storage/blobs/...",
    "metadata": {
      "width": 400,
      "height": 400
    },
    "created_at": "2025-11-19T10:30:00Z",
    "updated_at": "2025-11-19T10:30:00Z"
  }
}
```

### Created - New Image (201 Created)
```json
{
  "shared_apple_image": {
    "id": 2,
    "identifier": "my_new_image",
    "image_type": "branding",
    "description": "New image",
    "original_name": "new.png",
    "account_id": 1,
    "image_url": "https://example.com/rails/active_storage/blobs/...",
    "metadata": {},
    "created_at": "2025-11-19T11:00:00Z",
    "updated_at": "2025-11-19T11:00:00Z"
  }
}
```

### Validation Error (422 Unprocessable Entity)
```json
{
  "errors": {
    "identifier": ["can't be blank"],
    "image_type": ["is not included in the list"]
  }
}
```

### Not Found (404 Not Found)
```json
{
  "error": "Not found"
}
```

### Unauthorized (401 Unauthorized)
```json
{
  "error": "Unauthorized"
}
```

## Key Implementation Notes

1. **Account Scoping**: All queries use `Current.account.shared_apple_images` to ensure account isolation
2. **Pagination**: Defaults to page 1, 20 per_page, with a maximum of 100 per_page
3. **File Uploads**: Uses Rails ActiveStorage for attachment management
4. **Serialization**: Returns consistent JSON structure with optional URL inclusion
5. **Error Handling**: Proper HTTP status codes for all scenarios
6. **Authorization**: Inherited from `BaseController` which handles authentication
7. **Timestamps**: Automatically managed by Rails for created_at and updated_at
8. **Metadata**: Stored as JSONB in the database for flexibility

## Testing the Implementation

```bash
# Run the full test suite
bundle exec rspec spec/requests/api/v1/accounts/shared_apple_images_spec.rb -v

# Run a specific test
bundle exec rspec spec/requests/api/v1/accounts/shared_apple_images_spec.rb -e "returns all shared images"

# Run with documentation format
bundle exec rspec spec/requests/api/v1/accounts/shared_apple_images_spec.rb --format documentation

# Run with failure details
bundle exec rspec spec/requests/api/v1/accounts/shared_apple_images_spec.rb --format progress --failure-exit-status 1
```

## Debugging Tips

1. Check that `Current.account` is set properly in the request
2. Verify that image attachments are stored correctly in ActiveStorage
3. Use `binding.pry` to debug controller logic
4. Check Rails logs for ActiveRecord query details
5. Verify that the factory creates valid test data
6. Ensure test fixtures exist at `spec/assets/avatar.png` and `spec/fixtures/`
