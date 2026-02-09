# SharedAppleImage Presenter Usage Guide

## Overview

The `SharedAppleImagePresenter` provides clean JSON serialization for `SharedAppleImage` model instances used in Apple Messages for Business features.

## Files Created

1. **Model Methods** (`app/models/shared_apple_image.rb`)
   - `image_data_base64` - Returns base64-encoded image data
   - `image_url` - Returns Rails blob URL for preview
   - `image_attached?` - Returns boolean indicating if image is attached
   - `image_size` - Returns file size in bytes

2. **Presenter** (`app/presenters/shared_apple_image_presenter.rb`)
   - `as_json` - Returns hash with all fields (without base64 data)
   - `as_json_with_data` - Returns hash including base64-encoded image data
   - `SharedAppleImagePresenter.collection(images)` - Serializes array of images
   - `SharedAppleImagePresenter.collection_with_data(images)` - Serializes array with base64 data

## JSON Response Format

### Standard Response (without image data)

```json
{
  "id": 123,
  "account_id": 1,
  "identifier": "messages_png",
  "image_type": "system",
  "description": "Messages app icon",
  "original_name": "Messages.png",
  "metadata": {},
  "image_url": "/rails/active_storage/blobs/...",
  "image_attached": true,
  "image_size": 12345,
  "created_at": "2025-11-19T10:30:00.000Z",
  "updated_at": "2025-11-19T10:30:00.000Z"
}
```

### Response with Base64 Data

```json
{
  "id": 123,
  "account_id": 1,
  "identifier": "messages_png",
  "image_type": "system",
  "description": "Messages app icon",
  "original_name": "Messages.png",
  "metadata": {},
  "image_url": "/rails/active_storage/blobs/...",
  "image_attached": true,
  "image_size": 12345,
  "image_data_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "created_at": "2025-11-19T10:30:00.000Z",
  "updated_at": "2025-11-19T10:30:00.000Z"
}
```

## Controller Usage Examples

### Example 1: Index Action (List all images)

```ruby
class Api::V1::Accounts::SharedAppleImagesController < Api::V1::Accounts::BaseController
  def index
    @images = SharedAppleImage.where(account_id: Current.account.id)
    render json: SharedAppleImagePresenter.collection(@images)
  end
end
```

### Example 2: Show Action (Single image)

```ruby
def show
  @image = SharedAppleImage.find(params[:id])
  presenter = SharedAppleImagePresenter.new(@image)
  render json: presenter.as_json
end
```

### Example 3: Create Action (with base64 data in response)

```ruby
def create
  @image = SharedAppleImage.new(image_params)
  @image.account_id = Current.account.id

  if params[:image_data].present?
    decoded_data = Base64.strict_decode64(params[:image_data])
    filename = params[:filename] || "#{params[:identifier]}.jpg"

    @image.image.attach(
      io: StringIO.new(decoded_data),
      filename: filename,
      content_type: params[:content_type] || 'image/jpeg'
    )
  end

  if @image.save
    presenter = SharedAppleImagePresenter.new(@image)
    render json: presenter.as_json_with_data, status: :created
  else
    render json: { errors: @image.errors.full_messages }, status: :unprocessable_entity
  end
end

private

def image_params
  params.permit(:identifier, :image_type, :description, :original_name, :metadata)
end
```

### Example 4: Inline Serialization (no presenter instance)

For simple cases, you can use the model methods directly:

```ruby
def simple_show
  @image = SharedAppleImage.find(params[:id])

  render json: {
    id: @image.id,
    identifier: @image.identifier,
    image_url: @image.image_url,
    image_attached: @image.image_attached?,
    image_size: @image.image_size
  }
end
```

## Comparison with Existing Pattern

The SharedAppleImagePresenter follows the same pattern as the existing `AppleListPickerImage` serialization:

**Old Pattern (inline in controller):**
```ruby
def serialize_image(image)
  {
    id: image.id,
    identifier: image.identifier,
    description: image.description,
    # ... more fields
  }
end

def serialize_images(images)
  images.map { |img| serialize_image(img) }
end
```

**New Pattern (with presenter):**
```ruby
# Single image
SharedAppleImagePresenter.new(image).as_json

# Collection
SharedAppleImagePresenter.collection(images)
```

## Benefits

1. **Consistency**: All API responses have the same structure
2. **DRY**: No need to duplicate serialization logic across controllers
3. **Maintainability**: Changes to JSON structure happen in one place
4. **Testability**: Easy to test presenter in isolation
5. **Flexibility**: Can choose to include/exclude base64 data as needed

## Testing

```ruby
# spec/presenters/shared_apple_image_presenter_spec.rb
require 'rails_helper'

RSpec.describe SharedAppleImagePresenter do
  let(:image) { create(:shared_apple_image) }
  let(:presenter) { described_class.new(image) }

  describe '#as_json' do
    it 'returns correct structure' do
      json = presenter.as_json

      expect(json).to include(
        id: image.id,
        identifier: image.identifier,
        image_type: image.image_type,
        image_attached: true
      )
      expect(json[:image_data_base64]).to be_nil
    end
  end

  describe '#as_json_with_data' do
    it 'includes base64 data' do
      json = presenter.as_json_with_data

      expect(json[:image_data_base64]).to be_present
    end
  end
end
```

## Migration from Inline Serialization

If you have existing controllers using inline serialization methods:

1. Replace `serialize_image(image)` with `SharedAppleImagePresenter.new(image).as_json`
2. Replace `serialize_images(images)` with `SharedAppleImagePresenter.collection(images)`
3. Remove the private `serialize_image` and `serialize_images` methods
4. Test thoroughly to ensure JSON structure remains identical

## Related Files

- Model: `app/models/shared_apple_image.rb`
- Presenter: `app/presenters/shared_apple_image_presenter.rb`
- Similar pattern: `app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb`
