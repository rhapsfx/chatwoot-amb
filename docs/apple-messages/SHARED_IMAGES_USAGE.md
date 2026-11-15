# Apple Messages for Business - Shared Images User Guide

**Version**: 1.0
**Last Updated**: 2025-11-19
**Status**: Production Ready

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Using the Shared Image Selector](#using-the-shared-image-selector)
4. [Image Types Explained](#image-types-explained)
5. [Step-by-Step Guides](#step-by-step-guides)
6. [Uploading New Shared Images](#uploading-new-shared-images)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Shared vs Inbox-Specific Comparison](#shared-vs-inbox-specific-comparison)
10. [FAQ](#faq)
11. [Advanced Features](#advanced-features)
12. [Examples](#examples)
13. [Tips & Tricks](#tips--tricks)
14. [Need Help?](#need-help)

---

## Introduction

### What are Shared Images?

Shared images are reusable image assets that can be accessed across all Apple Messages inboxes in your Chatwoot account. Instead of uploading the same image (like your company logo or Messages app icon) to each inbox separately, you can upload it once as a shared image and use it everywhere.

### Benefits of Using Shared Images

- **Efficiency**: Upload once, use everywhere
- **Consistency**: Ensure brand consistency across all inboxes
- **Storage Optimization**: Reduce database storage by eliminating duplicates
- **Easier Management**: Update an image in one place, changes reflect everywhere
- **Performance**: Faster template loading with cached shared images
- **Organization**: Categorized images (System, Branding, Template) for easy browsing

### When to Use Shared vs Inbox-Specific Images

**Use Shared Images for:**
- Company logos and branding elements
- System icons (Messages app, calendar, time picker)
- Frequently used template headers
- Standard menu backgrounds
- Generic product icons

**Use Inbox-Specific Images for:**
- Location-specific store images
- One-time promotional campaign images
- Temporary seasonal content
- Test images during development
- Custom inbox branding overrides

---

## Getting Started

### Accessing Shared Images

Shared images can be accessed from three main areas in Chatwoot:

1. **Template Editor** (Settings → Templates)
   - When creating/editing List Pickers
   - When creating/editing Forms
   - When creating/editing Authentication templates

2. **Conversation Composer** (Active Conversation)
   - When sending a Time Picker message
   - When using quick templates with images

3. **Bot Configuration** (Settings → Bots)
   - When configuring Acoustic House Bot responses
   - When setting up automated menu flows

### Prerequisites

- **View Access**: All users (Agents and Administrators)
- **Upload Access**: Administrators only
- **Delete Access**: Administrators only
- **Override Access**: Administrators only

---

## Using the Shared Image Selector

### Interface Overview

The Shared Image Selector provides an intuitive interface for browsing and selecting images:

```
┌──────────────────────────────────────────────────────┐
│ Shared Images for: [Inbox Dropdown ▼]                │
├──────────────────────────────────────────────────────┤
│ [System] [Branding] [Template] ← Category Tabs       │
├──────────────────────────────────────────────────────┤
│ 🔍 Search by identifier or description...            │
├──────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│ │    📱    │ │    🏢    │ │    📅    │               │
│ │messages │ │apple    │ │calendar │ ← Image Grid    │
│ │  _png   │ │ _store  │ │  _icon  │                 │
│ └─────────┘ └─────────┘ └─────────┘                │
│                                                       │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐                │
│ │    🕐    │ │    📋    │ │    🎸    │               │
│ │  time   │ │  form   │ │ guitar  │                 │
│ │ _picker │ │ _header │ │  _menu  │                 │
│ └─────────┘ └─────────┘ └─────────┘                │
├──────────────────────────────────────────────────────┤
│ Selected: messages_png                               │
│ [Preview]                                             │
│ ┌─────────────────────┐                             │
│ │                     │                              │
│ │   📱 Messages App   │ ← Selected Image Preview    │
│ │                     │                              │
│ └─────────────────────┘                             │
├──────────────────────────────────────────────────────┤
│ [Upload New Image] [Clear Selection] [Close]         │
└──────────────────────────────────────────────────────┘
```

### Features Explained

#### Category Tabs
- **System**: Pre-loaded system icons (read-only for most users)
- **Branding**: Company-wide branding assets
- **Template**: Reusable template components

#### Search Functionality
- Real-time search as you type
- Searches both identifier and description fields
- Case-insensitive matching
- Partial word matching supported

#### Image Grid
- Visual thumbnails for quick identification
- Hover to see full details (identifier, description, type)
- Click to select an image
- Selected image shows blue border

#### Preview Panel
- Shows selected image at full size
- Displays image metadata
- Updates immediately on selection

#### Action Buttons
- **Upload New Image**: Opens upload dialog (Admin only)
- **Clear Selection**: Deselects current image
- **Close**: Closes selector without changes

---

## Image Types Explained

### System Images

**Purpose**: Core system icons that Apple Messages recognizes and displays specially

**Access**: Read-only for all users, managed by system administrators

**Common System Images**:
- `messages_png` - Messages app icon for received messages
- `calendar_icon` - Calendar icon for date/time pickers
- `time_picker_icon` - Clock icon for time selection
- `location_pin` - Map pin for location services
- `apple_pay_icon` - Apple Pay logo for payment flows

**Usage Notes**:
- These images follow Apple's design guidelines
- Cannot be deleted or modified by users
- Automatically available to all inboxes

### Branding Images

**Purpose**: Company-specific branding elements consistent across all customer touchpoints

**Access**: Uploadable by administrators, usable by all

**Common Branding Images**:
- `company_logo` - Main company logo
- `apple_store_logo` - Apple Store branding
- `brand_pattern` - Background patterns
- `signature_color` - Brand color swatches
- `retail_store_[location]` - Store-specific logos

**Usage Notes**:
- Should follow brand guidelines
- Updated centrally when rebranding occurs
- Can be overridden per inbox if needed

### Template Images

**Purpose**: Reusable images for common template patterns

**Access**: Uploadable by administrators, usable by all

**Common Template Images**:
- `form_header_blue` - Standard form header
- `menu_background` - Menu template background
- `success_checkmark` - Confirmation icon
- `error_warning` - Error state icon
- `loading_spinner` - Progress indicator

**Usage Notes**:
- Generic enough to work across multiple templates
- Not tied to specific campaigns
- Can be seasonal (upload new versions as needed)

---

## Step-by-Step Guides

### A. Using Shared Images in List Picker Templates

1. **Navigate to Template Editor**
   ```
   Settings → Templates → List Pickers → [Create New/Edit]
   ```

2. **Access Images Section**
   - Scroll to "Images" section in the template editor
   - You'll see two tabs: "Upload New" and "Use Shared Images"

3. **Select Shared Images Tab**
   - Click "Use Shared Images" tab
   - The shared image selector will appear

4. **Choose Your Inbox**
   - Select the target inbox from the dropdown
   - This determines which images are available

5. **Browse and Select Images**
   - Use category tabs to filter (System/Branding/Template)
   - Or search for specific image by name
   - Click on desired image to select it

6. **Map Images to List Items**
   - In your list picker sections, reference the image by identifier
   - Example: `image_identifier: "apple_store_logo"`

7. **Preview and Save**
   - Use the preview button to see how it looks
   - Click "Save Template" when satisfied

### B. Using Shared Images in Time Picker Messages

1. **Open Conversation**
   ```
   Conversations → Select Conversation → Compose Area
   ```

2. **Select Time Picker Message Type**
   - Click the message type dropdown
   - Select "Time Picker"

3. **Configure Time Settings**
   - Set available time slots
   - Configure timezone handling
   - Set event details

4. **Add Received Message Image**
   - In "Received Message" section
   - Toggle "Use Shared Image" switch ON
   - Click "Select Image" button
   - Choose from shared image selector
   - Preview shows below

5. **Add Reply Message Image (Optional)**
   - In "Reply Message" section
   - Toggle "Use Shared Image" switch ON
   - Select different image OR
   - Leave blank to auto-use received message image

6. **Send Message**
   - Review the complete time picker configuration
   - Click "Send" to deliver to customer

### C. Using Shared Images in Form Templates

1. **Navigate to Form Builder**
   ```
   Settings → Templates → Forms → [Create New/Edit]
   ```

2. **Access Messages Tab**
   - Click on "Messages" tab in form builder
   - See "Received Message" and "Reply Message" sections

3. **Configure Received Message**
   - Add your message text
   - Toggle "Use Shared Image" ON
   - Click "Browse Shared Images"
   - Select appropriate image (e.g., `form_header_blue`)

4. **Configure Reply Message**
   - Add reply message text
   - Toggle "Use Shared Image" ON
   - Select image OR leave blank for auto-sync with received

5. **Complete Form Configuration**
   - Add form fields
   - Set validation rules
   - Configure submission handling

6. **Save Form Template**
   - Preview the form flow
   - Click "Save Template"

### D. Using Shared Images in Bot Flows

1. **Access Bot Configuration**
   ```
   Settings → Bots → Acoustic House Bot → Configure
   ```

2. **Edit Menu Response**
   - Find the menu/list picker response
   - Click "Edit"

3. **Add Shared Images to Menu Items**
   - For each menu item, add:
   ```json
   {
     "title": "Find a Store",
     "subtitle": "Locate nearest Apple Store",
     "image_identifier": "apple_store_logo"
   }
   ```

4. **Save Bot Configuration**
   - Test the bot flow
   - Save changes

---

## Uploading New Shared Images

### Requirements

**User Role**: Administrator only

**File Requirements**:
- **Formats**: PNG, JPEG, GIF
- **Maximum Size**: 5MB
- **Minimum Resolution**: 400x400 pixels
- **Recommended**: 800x800 pixels for retina displays
- **Aspect Ratio**: 1:1 preferred for list items

### Upload Process

1. **Open Any Image Selector**
   - From List Picker, Time Picker, or Form editor
   - Click "Upload New Image" button

2. **Fill Upload Form**
   ```
   ┌─────────────────────────────────────┐
   │ Upload Shared Image                  │
   ├─────────────────────────────────────┤
   │ Identifier*: [________________]      │
   │ (snake_case, unique)                 │
   │                                       │
   │ Description: [________________]      │
   │ (Human-readable name)                │
   │                                       │
   │ Image Type*: [System ▼]              │
   │                                       │
   │ [Choose File] No file chosen         │
   │                                       │
   │ [Cancel] [Upload]                    │
   └─────────────────────────────────────┘
   ```

3. **Enter Image Details**
   - **Identifier**: Unique snake_case name (e.g., `holiday_banner_2024`)
   - **Description**: Human-friendly description
   - **Image Type**: Select System, Branding, or Template

4. **Select File**
   - Click "Choose File"
   - Browse to your image file
   - Select and confirm

5. **Upload Image**
   - Click "Upload" button
   - Wait for upload confirmation
   - Image immediately appears in selector

### Managing Existing Images

**Viewing Image Details**:
- Hover over any image in the selector
- See identifier, description, type, upload date

**Deleting Images** (Admin only):
- Hover over image
- Click delete (🗑️) icon
- Confirm deletion
- **Warning**: This is permanent and affects all templates using this image

**Updating Images**:
- Cannot edit existing images directly
- Upload new version with different identifier
- Update templates to use new identifier
- Delete old version when migration complete

---

## Best Practices

### Naming Conventions

**DO**:
- Use descriptive snake_case: `store_locator_icon`
- Include type in name: `logo_company_primary`
- Add context: `menu_header_holiday_2024`
- Be consistent: `icon_calendar`, `icon_location`, `icon_time`

**DON'T**:
- Use generic names: `image1`, `temp`, `test`
- Use spaces or special characters: `my image.png`
- Use camelCase: `storeLocatorIcon`
- Be too brief: `img`, `pic`, `i1`

### Image Optimization

**Before Upload**:
1. Resize to appropriate dimensions (800x800px recommended)
2. Compress using tools like TinyPNG or ImageOptim
3. Remove unnecessary metadata
4. Test on both light and dark backgrounds
5. Ensure transparency if needed (PNG format)

**File Size Guidelines**:
- Icons: < 50KB
- Logos: < 200KB
- Headers/Backgrounds: < 500KB
- Maximum: 5MB (hard limit)

### Organization Strategy

**System Images**:
- Reserve for Apple-specific icons only
- Don't upload custom icons as system type
- Keep consistent with Apple HIG

**Branding Images**:
- One primary logo per brand
- Consistent naming: `logo_[brand]_[variant]`
- Include all brand variations upfront

**Template Images**:
- Group by use case: `form_`, `menu_`, `auth_`
- Version seasonal content: `header_winter_2024`
- Archive old versions (delete after season)

### Performance Considerations

**Reuse Shared Images When**:
- Image appears in multiple templates
- Image is part of brand identity
- Image is unlikely to change frequently
- Multiple inboxes need the same image

**Use Inline Upload When**:
- Image is for one-time campaign
- Testing new designs
- Inbox requires unique variation
- Temporary promotional content

---

## Troubleshooting

### Common Issues and Solutions

#### Image Not Appearing in Selector

**Symptoms**: Uploaded image doesn't show up

**Solutions**:
1. Refresh the page (Cmd+R / Ctrl+R)
2. Check inbox selection in dropdown
3. Verify upload completed successfully
4. Check browser console for errors
5. Ensure you're looking in correct category tab

#### Upload Fails

**Error**: "Failed to upload image"

**Solutions**:
1. Check file size (must be < 5MB)
2. Verify file format (PNG, JPEG, GIF only)
3. Ensure unique identifier (not already used)
4. Check your admin permissions
5. Try different browser
6. Check network connection

#### Image Looks Blurry/Pixelated

**Symptoms**: Poor image quality in messages

**Solutions**:
1. Upload higher resolution (minimum 400x400px)
2. Use PNG for icons/logos (better for sharp edges)
3. Avoid excessive compression
4. Check original file quality
5. Re-upload at 2x resolution for retina displays

#### Can't Delete Image

**Error**: "Cannot delete image - in use"

**Solutions**:
1. Image is being used in active templates
2. Check all templates for references
3. Update templates to use different image first
4. Then retry deletion
5. Only admins can delete images

#### Image Wrong Size in Message

**Symptoms**: Image too large/small in Apple Messages

**Solutions**:
1. Follow Apple's recommended dimensions
2. List picker items: 100x100px display size
3. Headers: 375px width for mobile
4. Upload at 2x for retina (200x200px for 100x100px display)
5. Test on actual device

### Performance Issues

#### Slow Image Loading

**Solutions**:
1. Optimize images before upload
2. Use appropriate format (JPEG for photos, PNG for graphics)
3. Check account image limit (recommend < 100 images)
4. Clear browser cache
5. Remove unused images

#### Selector Takes Long to Open

**Solutions**:
1. Reduce total number of shared images
2. Archive seasonal/old images
3. Use search instead of browsing
4. Check network speed
5. Try different browser

---

## Shared vs Inbox-Specific Comparison

| Aspect | Shared Images | Inbox-Specific Images |
|--------|--------------|----------------------|
| **Scope** | Available to all inboxes in account | Single inbox only |
| **Storage** | One copy per account | One copy per inbox |
| **Management** | Centralized in shared library | Per-inbox management |
| **Upload Method** | Via shared selector or API | Inline in template editor |
| **Best For** | System icons, branding, common templates | Custom campaigns, temporary content |
| **Reusability** | High - use across all templates | Low - specific to inbox |
| **Update Process** | Update once, affects all uses | Update each inbox separately |
| **Access Control** | Admin upload, all can use | Inbox-specific permissions |
| **Performance** | Cached, faster loading | Loaded per request |
| **Backup** | Part of account backup | Part of inbox backup |

---

## FAQ

### General Questions

**Q: Can I use shared images across different Chatwoot accounts?**
A: No, shared images are scoped to a single account. Each account maintains its own library of shared images.

**Q: What happens to my existing inline/embedded images?**
A: They continue to work perfectly! The system uses a three-tier fallback: inbox-specific → shared → embedded images.

**Q: Can I override a shared image for a specific inbox?**
A: Yes, upload an inbox-specific image with the same identifier. The inbox-specific version will take priority.

**Q: Who can upload shared images?**
A: Only users with Administrator role can upload to the shared library.

**Q: Who can use shared images in templates?**
A: All users (both Administrators and Agents) can select and use shared images in their templates and messages.

**Q: Is there a limit to how many shared images I can have?**
A: No hard limit, but we recommend keeping it under 100 images per account for optimal performance.

**Q: Can I bulk upload images?**
A: Currently, images must be uploaded one at a time through the UI. Bulk upload via API is planned for future release.

### Technical Questions

**Q: What happens if I delete a shared image that's being used?**
A: Templates referencing the deleted image will show a missing image placeholder. Update templates before deleting.

**Q: How are shared images stored?**
A: Shared images use ActiveStorage with the same security and CDN delivery as other Chatwoot assets.

**Q: Can I programmatically upload shared images?**
A: Yes, via the API endpoint: `POST /api/v1/accounts/:account_id/shared_apple_images`

**Q: Do shared images count against my storage quota?**
A: Yes, but only once per account instead of once per inbox, saving significant storage.

**Q: Can I migrate inbox-specific images to shared?**
A: Yes, administrators can use the migration scripts or manually re-upload as shared images.

### Best Practice Questions

**Q: Should I upload all images as shared?**
A: No, use shared for reusable assets (logos, icons, headers). Use inbox-specific for temporary or unique content.

**Q: How should I handle seasonal images?**
A: Upload as template type with versioning (e.g., `header_christmas_2024`). Delete after season ends.

**Q: What's the best image format for icons?**
A: PNG with transparency for icons and logos. JPEG for photographs and backgrounds.

**Q: Should each store location have its own image?**
A: Depends on your needs. Use shared for common store logo, inbox-specific for location photos.

---

## Advanced Features

### Auto-Sync Functionality

#### Time Picker Auto-Sync
When sending a time picker message, the reply message automatically inherits the received message image unless explicitly overridden.

**How it works**:
1. Set received message image
2. Leave reply message image blank
3. System automatically uses received image for reply
4. Ensures visual consistency

**Override when needed**:
- Explicitly select different image for reply
- Auto-sync is disabled when reply image is set

#### Form Auto-Sync
Forms follow the same auto-sync pattern as time pickers.

**Benefits**:
- Saves time during configuration
- Ensures consistent user experience
- Reduces chance of mismatched images
- Follows Apple's design guidelines

### Search and Filter Capabilities

#### Advanced Search
- **Partial matching**: Type "logo" to find all logo images
- **Identifier search**: Type exact identifier like "messages_png"
- **Description search**: Search within descriptions
- **Real-time results**: Updates as you type

#### Smart Filtering
- **Category tabs**: Quick filter by type
- **Inbox scoping**: See only relevant images
- **Recently used**: (Coming soon) Quick access to recent selections

### Image Fallback System

The system implements a three-tier fallback mechanism:

```
1. Inbox-Specific Images (Highest Priority)
   ↓ (if not found)
2. Shared Images (Account-wide)
   ↓ (if not found)
3. Embedded Images (Template-specific)
```

**Benefits**:
- Never lose images during migration
- Graceful degradation
- Backward compatibility
- Flexible override system

---

## Examples

### Example 1: Company-Wide Branding Update

**Scenario**: Your company updates its logo and you need it reflected everywhere.

**Steps**:
1. Upload new logo as shared branding image:
   - Identifier: `logo_company_2024`
   - Type: Branding
2. Update templates to reference new identifier
3. All inboxes immediately show new logo
4. Delete old logo after verification

### Example 2: Multi-Store List Picker

**Scenario**: Create a store selector that works across all inboxes.

**Setup**:
```json
{
  "sections": [{
    "title": "Select Your Store",
    "items": [
      {
        "identifier": "store_nyc",
        "title": "New York - Fifth Avenue",
        "image_identifier": "apple_store_logo"
      },
      {
        "identifier": "store_sf",
        "title": "San Francisco - Union Square",
        "image_identifier": "apple_store_logo"
      }
    ]
  }]
}
```

**Result**: Same Apple Store logo appears for all locations across all inboxes.

### Example 3: Seasonal Campaign with Fallback

**Scenario**: Holiday campaign with special headers, but fallback to standard for other times.

**Implementation**:
1. Upload `form_header_holiday_2024` as template image
2. Use in holiday form templates
3. After season, delete holiday image
4. System automatically falls back to `form_header_standard`

### Example 4: Bot Menu with Icons

**Scenario**: Acoustic House Bot menu with consistent icons.

**Configuration**:
```json
{
  "menu_items": [
    {
      "title": "Store Hours",
      "image_identifier": "icon_clock"
    },
    {
      "title": "Find Location",
      "image_identifier": "icon_location"
    },
    {
      "title": "Book Appointment",
      "image_identifier": "icon_calendar"
    }
  ]
}
```

**Result**: Professional menu with consistent iconography.

---

## Tips & Tricks

### Pro Tips

💡 **Batch Upload Planning**: Before uploading, organize your images into folders matching the three types (System, Branding, Template).

💡 **Naming Convention Document**: Maintain a shared document with your team's image naming conventions for consistency.

💡 **Image Audit Schedule**: Quarterly review to remove unused images and update seasonal content.

💡 **Test on Devices**: Always test how images appear on actual iOS devices, not just browser previews.

💡 **Dark Mode Consideration**: Upload images that work on both light and dark backgrounds, or provide variants.

### Efficiency Shortcuts

**Quick Image Selection**:
- Type first few letters in search
- Use keyboard arrows to navigate
- Enter to select
- Escape to cancel

**Template Duplication**:
- Create base template with shared images
- Duplicate for variations
- Shared images automatically work in copies

**Bulk Updates via Database** (Advanced):
- Administrators can update image identifiers in database
- Useful for bulk renaming during reorganization
- Always backup before database modifications

### Hidden Features

**Image Metadata**:
- Hover over image for extended information
- Shows upload date, file size, last used

**Keyboard Navigation**:
- Tab through images
- Space to select
- Arrow keys for grid navigation

**Direct API Upload**:
- Bypass UI for automated uploads
- Useful for migration scripts
- Supports batch processing

---

## Need Help?

### Resources

**Documentation**:
- API Docs: `/docs/api/shared_apple_images_api.md`
- Technical Architecture: `/docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- Migration Guide: `/docs/apple-messages/IMAGE_MIGRATION_GUIDE.md`
- Implementation Status: `/docs/apple-messages/implementation/IMPLEMENTATION_COMPLETE.md`

**Support Channels**:
- Admin Dashboard: Check image fetch logs
- System Logs: `/log/development.log` for errors
- Support Team: Contact for enterprise support
- Community Forum: Share tips and solutions

### Diagnostic Tools

**Check Image Availability**:
```ruby
# Rails console command
rails runner "puts SharedAppleImage.where(account_id: 1).pluck(:identifier)"
```

**Verify Image Fallback**:
```ruby
# Test fallback hierarchy
rails runner "script/test_image_fallback.rb"
```

**Audit Image Usage**:
```ruby
# See which templates use which images
rails runner "script/audit_image_usage.rb"
```

### Contact Information

**For Technical Issues**:
- Check system logs first
- Gather error messages
- Note steps to reproduce
- Contact system administrator

**For Feature Requests**:
- Document use case
- Provide examples
- Submit through proper channels

---

## Summary

The Shared Images feature in Apple Messages for Business streamlines image management across your Chatwoot inboxes. By centralizing commonly used images, you can:

- Reduce storage overhead
- Maintain brand consistency
- Simplify template management
- Improve performance
- Accelerate template creation

Follow the best practices outlined in this guide to maximize the benefits of shared images while maintaining flexibility for inbox-specific customization.

**Remember**: Shared images are powerful for consistency, but don't force everything to be shared. Use the right tool for the right job - shared for common assets, inline for unique content.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-19
**Next Review**: 2026-02-19

For the latest updates to this guide, check the documentation repository.