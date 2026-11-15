# Apple Messages for Business - Image Handling Flow Analysis

## Executive Summary

The Chatwoot Apple Messages for Business system has a two-tier hybrid image architecture designed to support both account-wide shared images and inbox-specific images. Currently, there is **no image compression** implemented. Images flow through the system unmodified, stored at their original sizes in ActiveStorage.

**Current Limitations**:
- Maximum size: 5MB per image (enforced at upload, no reduction)
- Minimum resolution: 400x400 pixels
- No automatic compression or optimization
- Images stored uncompressed in ActiveStorage
- File size guidelines are only recommendations (Icons <50KB, Logos <200KB, Headers <500KB)

---

## 1. Image Upload & Storage Flow

### 1.1 Upload Entry Points

**Primary Controller: SharedAppleImagesController**
- File: `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/shared_apple_images_controller.rb`
- Endpoints:
  - `POST /api/v1/accounts/:account_id/shared_apple_images` (create)
  - `POST /api/v1/accounts/:account_id/shared_apple_images/:id/upload` (upload image)

**Legacy Controller: AppleAmbImagesController**
- File: `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb`
- Endpoints:
  - `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images` (create)
  - `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/bulk_upload` (bulk)
  - `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images/copy_from` (copy)

**Deprecated Controller: AppleListPickerImagesController**
- File: `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb`
- Status: Deprecated as of Nov 2025, will be removed Q2 2026

### 1.2 Upload Processing

Both controllers follow the same pattern:

```ruby
# From apple_amb_images_controller.rb (lines 16-40)
def create
  @image = @inbox.apple_list_picker_images.new(image_params)
  @image.account_id = Current.account.id

  if params[:image_file].present?
    # Direct file upload
    @image.image.attach(params[:image_file])
  elsif params[:image_data].present?
    # Base64 data from frontend
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
  end
end
```

**Key Issues for Compression**:
- Line 24: `decoded_data = Base64.strict_decode64(params[:image_data])` - No validation
- Line 28-32: Direct attachment with no processing
- No image validation, resizing, or compression before storage

### 1.3 Storage Models

**SharedAppleImage** (Account-scoped shared images)
- File: `/Users/rhaps/LocalGit/chatwoot/app/models/shared_apple_image.rb`
- Table: `shared_apple_images`
- Attachment: `image` (via `has_one_attached :image`)
- Types: 'system', 'branding', 'template'
- Max size check: None (enforced at API level, documentation only)

**AppleListPickerImage** (Inbox-specific images)
- File: `/Users/rhaps/LocalGit/chatwoot/app/models/apple_list_picker_image.rb`
- Table: `apple_list_picker_images`
- Attachment: `image` (via `has_one_attached :image`)
- Max size check: None (enforced at API level, documentation only)

### 1.4 ActiveStorage Configuration

File: `/Users/rhaps/LocalGit/chatwoot/config/storage.yml`

Supports multiple backends:
- Local disk: `service: Disk`
- AWS S3: `service: S3`
- Google Cloud Storage: `service: GCS`
- Azure Blob Storage: `service: AzureStorage`
- S3-compatible (DigitalOcean, Minio): `service: S3`

**No image processing configured** - ActiveStorage uses default behavior

---

## 2. Image Retrieval & Encoding Flow

### 2.1 ImageFetchService (Three-Tier Fallback)

File: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/image_fetch_service.rb`

**Three-tier hierarchy when fetching images**:
```
Tier 1: AppleListPickerImage (inbox-specific) - HIGHEST PRIORITY
  ↓ (if not found)
Tier 2: SharedAppleImage (account-wide)
  ↓ (if not found)
Tier 3: Embedded images (content_attributes['images'])
```

**Retrieval and Encoding** (lines 69-144):

```ruby
def fetch_from_inbox(identifier)
  picker_image = AppleListPickerImage
                 .where(inbox_id: @inbox_id, identifier: identifier)
                 .includes(image_attachment: :blob)
                 .first
  
  return nil unless picker_image&.image&.attached?
  
  {
    identifier: identifier,
    data: Base64.strict_encode64(picker_image.image.download),  # LINE 98
    description: picker_image.description || identifier,
    source: 'inbox'
  }
end

def fetch_from_shared(identifier)
  shared_image = SharedAppleImage
                 .where(account_id: @account_id, identifier: identifier)
                 .includes(image_attachment: :blob)
                 .first
  
  return nil unless shared_image&.image&.attached?
  
  {
    identifier: identifier,
    data: Base64.strict_encode64(shared_image.image.download),  # LINE 119
    description: shared_image.description || identifier,
    source: "shared_#{shared_image.image_type}"
  }
end
```

**Key Issues**:
- Line 98, 119: `Base64.strict_encode64(image.download)` - Full resolution file downloaded and encoded
- Downloads entire uncompressed image into memory
- Encodes to base64 (33% size increase)
- No option to get optimized/compressed versions

### 2.2 Image Size Data Available

**Model Methods** (SharedAppleImage):
```ruby
def image_size
  return nil unless image.attached?
  image.byte_size  # Available but not used for compression
end
```

The `byte_size` is available but only used for informational purposes.

---

## 3. Image Sending to Apple MSP

### 3.1 Send Services Integration

**SendListPickerService** (lines 307-319):
```ruby
def fetch_and_encode_images(identifiers)
  return [] if identifiers.empty?
  
  AppleMessagesForBusiness::ImageFetchService.new(
    account_id: message.account_id,
    inbox_id: message.inbox_id,
    embedded_images: content_attributes['images']
  ).fetch_and_encode(identifiers)
end
```

**SendTimePickerService** (lines 236-245):
```ruby
def fetch_and_encode_images(identifiers)
  return [] if identifiers.empty?
  
  AppleMessagesForBusiness::ImageFetchService.new(
    account_id: message.account_id,
    inbox_id: message.inbox_id,
    embedded_images: content_attributes['images']
  ).fetch_and_encode(identifiers)
end
```

Both services call `ImageFetchService.fetch_and_encode()` which returns:
```ruby
[
  { identifier: 'msg_icon', data: 'base64_string...', description: '...', source: 'inbox' },
  { identifier: 'logo', data: 'base64_string...', description: '...', source: 'shared_system' }
]
```

Images are included in the final Apple MSP payload as base64-encoded data.

### 3.2 Image Saving During Send

**SendListPickerService.save_images_to_storage()** (lines 85-217):

When user sends a message with embedded images:
```ruby
def save_images_to_storage
  images = content_attributes['images'] || []
  
  # Line 172: Decode base64 without validation
  decoded_data = Base64.strict_decode64(image_data['data'])
  
  # Line 175-180: Basic size check (10MB max, could be compressed more)
  max_size = 10.megabytes
  if decoded_data.bytesize > max_size
    Rails.logger.error "[AMB ListPicker] Image exceeds max size"
    failed_count += 1
    next
  end
  
  # Line 187-191: Attach without compression
  picker_image.image.attach(
    io: StringIO.new(decoded_data),
    filename: filename,
    content_type: content_type
  )
end
```

**Key Issues**:
- Line 172: Only basic base64 validation, no content validation
- Line 175-180: Only checks against 10MB max (very loose)
- Line 187-191: No processing before ActiveStorage attachment
- Processing done in batches of 10 images (line 115), but each image loaded fully into memory

---

## 4. Apple's Image Requirements

### 4.1 Specifications from Documentation

File: `/Users/rhaps/LocalGit/chatwoot/docs/apple-messages/SHARED_IMAGES_USAGE.md` (lines 341-440)

**File Requirements**:
- **Formats**: PNG, JPEG, GIF
- **Maximum Size**: 5MB (enforced only at API level)
- **Minimum Resolution**: 400x400 pixels
- **Recommended**: 800x800 pixels for retina displays
- **Aspect Ratio**: 1:1 preferred for list items

**File Size Guidelines**:
- Icons: <50KB
- Logos: <200KB
- Headers/Backgrounds: <500KB

**Best Practices** (lines 430-435):
1. Resize to appropriate dimensions (800x800px recommended)
2. Compress using TinyPNG or ImageOptim
3. Remove unnecessary metadata
4. Test on light and dark backgrounds
5. Ensure transparency if needed (PNG format)

### 4.2 Missing Specifications

Looking through documentation and code, NO specific information about:
- Maximum payload size for Apple MSP API calls
- Recommended base64 size limits
- Bandwidth or performance recommendations
- Device display resolution guidelines
- Data URL size limits in Messages app

---

## 5. Image Processing Dependencies

### 5.1 Current Dependencies

**Gemfile** (line 56):
```ruby
gem 'image_processing'
```

**Status**: Installed but NOT used anywhere in the codebase

**What image_processing provides**:
- Wrapper around ImageMagick or libvips
- Can resize, crop, format conversion, compression
- But requires explicit usage - currently no integration

### 5.2 Image Detection (Current Implementation)

**SendListPickerService.determine_content_type()** (lines 219-235):
```ruby
def determine_content_type(data, filename)
  # Magic byte detection
  return 'image/png' if data[0..3] == "\x89PNG"
  return 'image/jpeg' if data[0..1] == "\xFF\xD8"
  return 'image/gif' if data[0..2] == 'GIF'
  return 'image/webp' if data[8..11] == 'WEBP'
  
  # Fallback to filename extension
  ext = File.extname(filename).downcase
  case ext
  when '.png' then 'image/png'
  when '.jpg', '.jpeg' then 'image/jpeg'
  when '.gif' then 'image/gif'
  when '.webp' then 'image/webp'
  else 'image/jpeg' # default
  end
end
```

This only detects format, no processing.

---

## 6. Current Validation & Size Checks

### 6.1 Upload Level

**AppleAmbImagesController**:
- No validation before attachment
- No size check shown in code
- API-level size must be enforced elsewhere (likely in middleware or before_action)

**SharedAppleImagesController**:
- Line 59: `attach_image if image_provided?`
- Line 59 calls private method, no validation shown

### 6.2 Sending Level

**SendListPickerService.save_images_to_storage()** (lines 175-180):
```ruby
max_size = 10.megabytes
if decoded_data.bytesize > max_size
  Rails.logger.error "[AMB ListPicker] Image exceeds max size"
  failed_count += 1
  next
end
```

Only check is 10MB max when saving images from user message.

### 6.3 Retrieval Level

**ImageFetchService**:
- No size validation when encoding to base64
- Could result in very large base64 strings sent to Apple MSP

---

## 7. Memory & Performance Considerations

### 7.1 Current Memory Usage

**ImageFetchService.fetch_and_encode()** (lines 96-101):
```ruby
{
  identifier: identifier,
  data: Base64.strict_encode64(picker_image.image.download),  # ENTIRE file in memory
  description: picker_image.description || identifier,
  source: 'inbox'
}
```

**Issues**:
- `image.download` loads entire file into memory
- `Base64.strict_encode64()` creates base64 copy in memory
- Two copies of file in memory simultaneously
- With 5MB file: ~10MB memory per image

**SendListPickerService.save_images_to_storage()** (lines 121-213):
```ruby
images.each_slice(batch_size).with_index do |batch, batch_index|
  batch.each do |image_data|
    decoded_data = Base64.strict_decode64(image_data['data'])  # LINE 172
    # ... process image ...
  end
end
```

**Issues**:
- Batch processing set to 10 images (line 115)
- Each batch fully decoded into memory
- For 10 images at 1MB each = 10MB memory per batch
- Could be multiple batches in flight

### 7.2 I/O Performance

**ImageFetchService**:
- Queries database for image record
- Downloads full file from ActiveStorage (S3, GCS, or local disk)
- Encodes to base64
- Returns as string

No streaming or chunking - all loaded into memory before returning.

---

## 8. API Payload Size Considerations

### 8.1 Base64 Encoding Overhead

Base64 increases size by ~33%:
- 300KB PNG → 400KB base64 string
- 5MB image → 6.67MB base64 string

### 8.2 Multiple Images

**Typical message with list picker**:
- Header image: ~1MB → 1.33MB base64
- 3 list items with images: ~300KB each → 1.2MB base64 total
- Total payload: ~3.5MB+ before AppleMessagesForBusiness wrapper

### 8.3 Apple MSP Unknown Limits

Documentation shows:
- Custom payload size limit: 102KB max
- But image payloads are in `interactiveData`, unclear if same limit applies
- No explicit documentation found about image payload limits

---

## 9. Current Compression Points & Opportunities

### 9.1 Where Compression Could Be Added

**Option 1: At Upload Time** (Aggressive)
- Resize images to recommended dimensions
- Compress JPEG quality
- Strip metadata
- Convert formats if beneficial
- Store compressed version only

**Option 2: At Retrieval Time** (Flexible)
- Generate multiple versions (thumbnails, optimized)
- Use content negotiation (request compression)
- Stream encoding rather than in-memory

**Option 3: Hybrid** (Recommended)
- Validate & normalize at upload (size, format, dimensions)
- Store optimized version as primary
- Cache different resolutions
- Lazy-generate variants on demand

### 9.2 Implementation Points

```
UPLOAD FLOW:
Frontend (image)
  ↓
AppleAmbImagesController.create / upload
  ↓
[COMPRESSION OPPORTUNITY #1: Validate & optimize here]
  ↓
ActiveStorage.attach
  ↓
SharedAppleImage / AppleListPickerImage

RETRIEVAL FLOW:
SendListPickerService.fetch_and_encode_images
  ↓
ImageFetchService.fetch_and_encode
  ↓
[COMPRESSION OPPORTUNITY #2: Process here before base64]
  ↓
Base64.strict_encode64 (adds 33% overhead)
  ↓
Apple MSP Payload
```

---

## 10. Key Files Summary

| File | Purpose | Size | Key Methods |
|------|---------|------|-------------|
| `app/models/shared_apple_image.rb` | Account-scoped image model | 62 lines | `image_data_base64`, `image_url`, `image_size` |
| `app/models/apple_list_picker_image.rb` | Inbox-scoped image model | 60 lines | `image_data_base64`, `image_url` |
| `app/controllers/api/v1/accounts/shared_apple_images_controller.rb` | Shared image API | 150+ lines | `create`, `upload`, `index` |
| `app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb` | Inbox image API | 216 lines | `create`, `bulk_upload`, `copy_from` |
| `app/services/apple_messages_for_business/image_fetch_service.rb` | Image retrieval & encoding | 145 lines | `fetch_and_encode`, `fetch_single_image` |
| `app/services/apple_messages_for_business/send_list_picker_service.rb` | List picker message send | 356 lines | `fetch_and_encode_images`, `save_images_to_storage` |
| `app/services/apple_messages_for_business/send_time_picker_service.rb` | Time picker message send | 293 lines | `fetch_and_encode_images`, `save_images_to_storage` |
| `config/storage.yml` | ActiveStorage config | 45 lines | Storage backend configuration |
| `Gemfile` | Dependencies | Line 56 | `gem 'image_processing'` (unused) |

---

## 11. Recommendations for Compression Implementation

### 11.1 Immediate Opportunities

1. **Strip Metadata** (5-15% size reduction)
   - EXIF, IPTC, color profiles
   - No performance impact
   - Can be done with `image_processing` gem

2. **Format Optimization** (20-40% reduction)
   - JPEG quality tuning (80-85% quality)
   - PNG quantization for list items
   - Convert RGBA to RGB when possible
   - Use WebP for modern clients

3. **Dimension Validation** (if oversized)
   - Resize to 800x800px max for recommended
   - Reduce if larger than needed
   - Preserve 1:1 aspect ratio for list items

### 11.2 Strategic Integration Points

**Validation Layer**: New service `AppleMessagesForBusiness::ImageValidationService`
- Validate format, dimensions, size
- Detect oversized images
- Recommend optimizations

**Compression Layer**: New service `AppleMessagesForBusiness::ImageCompressionService`
- JPEG quality optimization
- PNG quantization
- Format conversion
- Metadata stripping

**Processing Layer**: Extend ActiveStorage
- Variants for different use cases
- Thumbnail generation
- Cached optimized versions

---

## 12. No Existing Image Processing

**Critical Finding**: Despite `image_processing` gem being in Gemfile, it is:
- NOT used anywhere in AMB code
- NOT configured in Rails
- NOT integrated with ActiveStorage

**Current state**: All images stored and retrieved at original size/quality.

