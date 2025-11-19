# SharedAppleImages REST API Documentation

## Overview

The SharedAppleImages API provides endpoints for managing shared image resources used across Apple Messages for Business features. These images are account-level resources that can be reused across multiple inboxes, templates, and message types.

### Purpose

- Centralized management of Apple Messages images at the account level
- Support for system, branding, and template-specific images
- Eliminates duplication by sharing images across inboxes
- Provides consistent image management for list pickers, time pickers, forms, and rich links

### Authentication

All endpoints require authentication via API access token.

**Required Headers:**
```
api_access_token: your-api-access-token
Content-Type: application/json
```

### Base URL Structure

```
https://your-domain.com/api/v1/accounts/:account_id/shared_apple_images
```

**Path Parameters:**
- `account_id` (required): The ID of the account

---

## Endpoints

### 1. List All Shared Images

**GET** `/api/v1/accounts/:account_id/shared_apple_images`

Returns a paginated list of all shared Apple images for the account.

#### Query Parameters

| Parameter | Type | Required | Description | Default |
|-----------|------|----------|-------------|---------|
| `page` | integer | No | Page number for pagination | 1 |
| `per_page` | integer | No | Items per page (max: 100) | 20 |
| `image_type` | string | No | Filter by type: `system`, `branding`, or `template` | - |
| `search` | string | No | Search by identifier or description | - |

#### Response Format (Success - 200 OK)

```json
{
  "images": [
    {
      "id": 1,
      "identifier": "menu_icon_messages",
      "original_name": "messages-icon.png",
      "image_type": "system",
      "description": "Default Messages app icon for menus",
      "metadata": {
        "width": 128,
        "height": 128,
        "format": "png"
      },
      "image_url": "https://storage.example.com/images/abc123.png",
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "per_page": 20
}
```

#### Example Request

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images?page=1&per_page=10&image_type=system" \
  -H "api_access_token: your-api-access-token"
```

---

### 2. Get Single Image

**GET** `/api/v1/accounts/:account_id/shared_apple_images/:id`

Retrieves details of a specific shared Apple image.

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `account_id` | integer | Yes | The account ID |
| `id` | integer | Yes | The shared image ID |

#### Response Format (Success - 200 OK)

```json
{
  "id": 1,
  "identifier": "menu_icon_messages",
  "original_name": "messages-icon.png",
  "image_type": "system",
  "description": "Default Messages app icon for menus",
  "metadata": {
    "width": 128,
    "height": 128,
    "format": "png",
    "size_bytes": 8192,
    "content_type": "image/png"
  },
  "image_url": "https://storage.example.com/images/abc123.png",
  "base64_data": "data:image/png;base64,iVBORw0KGgoAAAANS...",
  "created_at": "2025-01-15T10:00:00Z",
  "updated_at": "2025-01-15T10:00:00Z"
}
```

#### Example Request

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1" \
  -H "api_access_token: your-api-access-token"
```

---

### 3. Create Shared Image

**POST** `/api/v1/accounts/:account_id/shared_apple_images`

Creates a new shared Apple image with metadata (without uploading the actual image file).

#### Request Body

```json
{
  "identifier": "hero_image_welcome",
  "original_name": "welcome-hero.jpg",
  "image_type": "branding",
  "description": "Welcome hero image for time pickers",
  "metadata": {
    "width": 1024,
    "height": 768,
    "usage": ["time_picker", "list_picker"]
  }
}
```

#### Request Body Parameters

| Parameter | Type | Required | Description | Validation |
|-----------|------|----------|-------------|------------|
| `identifier` | string | Yes | Unique identifier for the image | Must be unique per account, alphanumeric with underscores |
| `original_name` | string | No | Original filename | - |
| `image_type` | string | Yes | Type of image | Must be: `system`, `branding`, or `template` |
| `description` | text | No | Description of the image | - |
| `metadata` | object | No | Additional metadata | JSON object |

#### Response Format (Success - 201 Created)

```json
{
  "id": 2,
  "identifier": "hero_image_welcome",
  "original_name": "welcome-hero.jpg",
  "image_type": "branding",
  "description": "Welcome hero image for time pickers",
  "metadata": {
    "width": 1024,
    "height": 768,
    "usage": ["time_picker", "list_picker"]
  },
  "image_url": null,
  "created_at": "2025-01-15T11:00:00Z",
  "updated_at": "2025-01-15T11:00:00Z"
}
```

#### Example Request

```bash
curl -X POST \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images" \
  -H "api_access_token: your-api-access-token" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "hero_image_welcome",
    "original_name": "welcome-hero.jpg",
    "image_type": "branding",
    "description": "Welcome hero image for time pickers"
  }'
```

---

### 4. Update Shared Image

**PATCH** `/api/v1/accounts/:account_id/shared_apple_images/:id`

Updates metadata for an existing shared Apple image.

#### Request Body

```json
{
  "description": "Updated description for the image",
  "metadata": {
    "width": 1024,
    "height": 768,
    "updated": true
  }
}
```

#### Request Body Parameters

| Parameter | Type | Required | Description | Notes |
|-----------|------|----------|-------------|-------|
| `description` | text | No | Updated description | - |
| `metadata` | object | No | Updated metadata | Merges with existing metadata |
| `image_type` | string | No | Updated type | Must be: `system`, `branding`, or `template` |

**Note:** The `identifier` cannot be updated once created to maintain referential integrity.

#### Response Format (Success - 200 OK)

```json
{
  "id": 2,
  "identifier": "hero_image_welcome",
  "original_name": "welcome-hero.jpg",
  "image_type": "branding",
  "description": "Updated description for the image",
  "metadata": {
    "width": 1024,
    "height": 768,
    "updated": true
  },
  "image_url": "https://storage.example.com/images/def456.jpg",
  "created_at": "2025-01-15T11:00:00Z",
  "updated_at": "2025-01-15T12:00:00Z"
}
```

#### Example Request

```bash
curl -X PATCH \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/2" \
  -H "api_access_token: your-api-access-token" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Updated welcome hero image",
    "metadata": {"updated": true}
  }'
```

---

### 5. Delete Shared Image

**DELETE** `/api/v1/accounts/:account_id/shared_apple_images/:id`

Deletes a shared Apple image and its associated file.

#### Response Format (Success - 200 OK)

```json
{
  "message": "Shared image deleted successfully"
}
```

#### Example Request

```bash
curl -X DELETE \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/2" \
  -H "api_access_token: your-api-access-token"
```

---

### 6. List System Images

**GET** `/api/v1/accounts/:account_id/shared_apple_images/system_images`

Returns all images with `image_type = 'system'`.

#### Query Parameters

Same as the main index endpoint (page, per_page, search).

#### Response Format

Same structure as the main index endpoint, but filtered to system images only.

#### Example Request

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/system_images" \
  -H "api_access_token: your-api-access-token"
```

---

### 7. List Branding Images

**GET** `/api/v1/accounts/:account_id/shared_apple_images/branding_images`

Returns all images with `image_type = 'branding'`.

#### Query Parameters

Same as the main index endpoint (page, per_page, search).

#### Response Format

Same structure as the main index endpoint, but filtered to branding images only.

#### Example Request

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/branding_images" \
  -H "api_access_token: your-api-access-token"
```

---

### 8. List Template Images

**GET** `/api/v1/accounts/:account_id/shared_apple_images/template_images`

Returns all images with `image_type = 'template'`.

#### Query Parameters

Same as the main index endpoint (page, per_page, search).

#### Response Format

Same structure as the main index endpoint, but filtered to template images only.

#### Example Request

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/template_images" \
  -H "api_access_token: your-api-access-token"
```

---

### 9. Upload Image File

**POST** `/api/v1/accounts/:account_id/shared_apple_images/:id/upload`

Uploads the actual image file to an existing shared image record.

#### Request Format

Multipart form data with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image` | file | Yes | The image file to upload |

#### Supported File Formats

- PNG (.png)
- JPEG (.jpg, .jpeg)
- GIF (.gif)
- WebP (.webp)

#### File Size Limits

- Maximum file size: 10MB
- Recommended dimensions: 1024x1024 or smaller for optimal performance

#### Response Format (Success - 200 OK)

```json
{
  "id": 2,
  "identifier": "hero_image_welcome",
  "original_name": "welcome-hero.jpg",
  "image_type": "branding",
  "description": "Welcome hero image for time pickers",
  "metadata": {
    "width": 1024,
    "height": 768,
    "format": "jpeg",
    "size_bytes": 204800
  },
  "image_url": "https://storage.example.com/images/def456.jpg",
  "created_at": "2025-01-15T11:00:00Z",
  "updated_at": "2025-01-15T13:00:00Z"
}
```

#### Example Request

```bash
curl -X POST \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/2/upload" \
  -H "api_access_token: your-api-access-token" \
  -F "image=@/path/to/welcome-hero.jpg"
```

---

### 10. Remove Image File

**DELETE** `/api/v1/accounts/:account_id/shared_apple_images/:id/remove_image`

Removes the image file from a shared image record without deleting the record itself.

#### Response Format (Success - 200 OK)

```json
{
  "message": "Image file removed successfully",
  "id": 2,
  "identifier": "hero_image_welcome"
}
```

#### Example Request

```bash
curl -X DELETE \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/2/remove_image" \
  -H "api_access_token: your-api-access-token"
```

---

## Data Models

### SharedAppleImage Schema

```ruby
{
  id: bigint (primary key),
  account_id: bigint (required, foreign key to accounts),
  identifier: string (required, unique per account),
  original_name: string,
  image_type: string (required, enum: ["system", "branding", "template"]),
  description: text,
  metadata: jsonb,
  created_at: datetime,
  updated_at: datetime
}
```

### Field Descriptions

| Field | Type | Description | Validation Rules |
|-------|------|-------------|------------------|
| `id` | bigint | Unique identifier | Auto-generated |
| `account_id` | bigint | Associated account | Required, must exist |
| `identifier` | string | Unique identifier within account | Required, unique per account, alphanumeric with underscores |
| `original_name` | string | Original filename | Optional, max 255 characters |
| `image_type` | string | Classification of image | Required, must be: `system`, `branding`, or `template` |
| `description` | text | Human-readable description | Optional |
| `metadata` | jsonb | Flexible metadata storage | Optional, JSON object |
| `created_at` | datetime | Record creation timestamp | Auto-generated |
| `updated_at` | datetime | Last modification timestamp | Auto-generated |

### Image Type Definitions

- **`system`**: Core system images (icons, default avatars, UI elements)
- **`branding`**: Brand-specific images (logos, hero images, backgrounds)
- **`template`**: Template-specific images used in message templates

---

## Error Responses

### Common Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| 400 | `bad_request` | Invalid request parameters |
| 401 | `unauthorized` | Missing or invalid authentication |
| 403 | `forbidden` | Insufficient permissions |
| 404 | `not_found` | Resource not found |
| 409 | `conflict` | Duplicate identifier |
| 422 | `unprocessable_entity` | Validation errors |
| 500 | `internal_server_error` | Server error |

### Error Response Format

```json
{
  "error": "Validation failed",
  "errors": [
    "Identifier has already been taken",
    "Image type is not included in the list"
  ],
  "details": "Additional context about the error"
}
```

### Validation Error Example (422)

```json
{
  "error": "Validation failed",
  "errors": {
    "identifier": ["has already been taken"],
    "image_type": ["is not included in the list"],
    "account": ["must exist"]
  }
}
```

### Not Found Error Example (404)

```json
{
  "error": "Shared image not found",
  "details": "No shared image found with ID 999"
}
```

### File Upload Error Example (400)

```json
{
  "error": "File upload failed",
  "details": "File size exceeds maximum limit of 10MB"
}
```

---

## Usage Examples

### 1. Upload a System Image

```bash
# Step 1: Create the image record
curl -X POST \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images" \
  -H "api_access_token: your-api-access-token" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "menu_icon_messages",
    "image_type": "system",
    "description": "Messages app icon for menus"
  }'

# Response: { "id": 1, ... }

# Step 2: Upload the actual image file
curl -X POST \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1/upload" \
  -H "api_access_token: your-api-access-token" \
  -F "image=@/path/to/messages-icon.png"
```

### 2. List All Branding Images

```bash
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/branding_images?page=1&per_page=50" \
  -H "api_access_token: your-api-access-token"
```

### 3. Update Image Metadata

```bash
curl -X PATCH \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1" \
  -H "api_access_token: your-api-access-token" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Primary Messages app icon - updated",
    "metadata": {
      "version": "2.0",
      "approved_by": "design_team",
      "usage_notes": "Use for all message-related menus"
    }
  }'
```

### 4. Search for Images

```bash
# Search by identifier or description
curl -X GET \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images?search=messages&image_type=system" \
  -H "api_access_token: your-api-access-token"
```

### 5. Delete an Image

```bash
# This removes both the record and the file
curl -X DELETE \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1" \
  -H "api_access_token: your-api-access-token"
```

### 6. Replace an Image File

```bash
# Remove the old file first
curl -X DELETE \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1/remove_image" \
  -H "api_access_token: your-api-access-token"

# Upload the new file
curl -X POST \
  "https://your-domain.com/api/v1/accounts/1/shared_apple_images/1/upload" \
  -H "api_access_token: your-api-access-token" \
  -F "image=@/path/to/new-messages-icon.png"
```

---

## Best Practices

### Image Naming Conventions

- Use descriptive, lowercase identifiers with underscores: `menu_icon_messages`, `hero_image_welcome`
- Include context in the identifier: `time_picker_morning_shift`, `list_picker_guitar_acoustic`
- Avoid generic names: use `branding_logo_primary` instead of just `logo`

### Image Organization

1. **System Images**: Reserve for UI components that rarely change
2. **Branding Images**: Use for company/brand-specific visuals
3. **Template Images**: Use for images specific to message templates

### Performance Optimization

- Compress images before uploading (PNG optimization, JPEG quality 85%)
- Use appropriate dimensions (avoid uploading 4K images for 128px icons)
- Cache image URLs on the frontend when possible
- Use the `metadata` field to store dimensions to avoid client-side image loading for layout

### Error Handling

```javascript
// Frontend example
async function uploadSharedImage(accountId, imageData, file) {
  try {
    // Create the image record first
    const response = await fetch(`/api/v1/accounts/${accountId}/shared_apple_images`, {
      method: 'POST',
      headers: {
        'api_access_token': apiToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(imageData)
    });

    if (!response.ok) {
      const error = await response.json();
      console.error('Failed to create image record:', error);
      return;
    }

    const imageRecord = await response.json();

    // Upload the file
    const formData = new FormData();
    formData.append('image', file);

    const uploadResponse = await fetch(
      `/api/v1/accounts/${accountId}/shared_apple_images/${imageRecord.id}/upload`,
      {
        method: 'POST',
        headers: {
          'api_access_token': apiToken
        },
        body: formData
      }
    );

    if (!uploadResponse.ok) {
      const error = await uploadResponse.json();
      console.error('Failed to upload image file:', error);
      // Consider deleting the record if file upload fails
      await deleteImageRecord(accountId, imageRecord.id);
      return;
    }

    return await uploadResponse.json();
  } catch (error) {
    console.error('Network error:', error);
  }
}
```

### Migration from Inbox-Specific Images

When migrating from inbox-specific images to shared images:

1. Identify common images across inboxes
2. Create shared image records with consistent identifiers
3. Upload images once at the account level
4. Update references in templates and messages
5. Remove duplicates from individual inboxes

---

## Rate Limits

- **General API calls**: 60 requests per minute per account
- **File uploads**: 20 uploads per minute per account
- **Maximum file size**: 10MB per image
- **Maximum images per account**: 1000 (configurable)

---

## Versioning

This documentation covers API version 1 (`/api/v1/`). Future versions will be documented separately with migration guides.

---

## Support

For API support, please contact your account manager or submit a support ticket through the admin dashboard.