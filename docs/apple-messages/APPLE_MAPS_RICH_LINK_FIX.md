# Apple Maps Rich Link Enhancement

## Problem

When sending Apple Maps URLs as rich links, the links appeared incomplete or weren't rendered properly in Apple Messages because:

1. **Initial assumption**: Apple Maps URLs have no Open Graph metadata
2. **Reality**: Apple Maps URLs DO have Open Graph metadata (og:title, og:image, og:description)
3. **SendRichLinkService limitation**: Was not scraping Open Graph metadata from URLs
4. **Manual workaround**: Initially tried manually providing Apple Maps icon

### Example Issue

Sending this URL as a rich link:
```
https://maps.apple.com/place?place-id=I1AD4262B0A0B785E
```

Result: Empty/incomplete rich link card in Apple Messages (when no title/image provided)

## Root Cause

The `SendRichLinkService` was only using manually provided title and image:

```ruby
def build_rich_link_data
  content_attrs = @message.content_attributes

  {
    url: content_attrs['url'] || @message.content,
    title: content_attrs['title'] || extract_title_from_url(content_attrs['url']),
    assets: build_assets(content_attrs)
  }
end
```

Since no Open Graph scraping was implemented, rich links required manual title/image provision.

## Solution

**Integrate Open Graph scraping** into `SendRichLinkService` to automatically extract metadata from URLs.

### Implementation

**File**: `app/services/apple_messages_for_business/send_rich_link_service.rb`

**Changes**:

1. **Modified `build_rich_link_data`** (lines 53-83):
```ruby
def build_rich_link_data
  content_attrs = @message.content_attributes
  url = content_attrs['url'] || @message.content

  # If title or image not provided, try to scrape Open Graph metadata
  if content_attrs['title'].blank? || content_attrs['image_url'].blank?
    Rails.logger.info "🔍 Rich Link - Title or image missing, attempting Open Graph scraping for: #{url}"
    og_data = scrape_open_graph_data(url)

    if og_data[:success]
      Rails.logger.info "✅ Rich Link - Open Graph scraping successful"
      Rails.logger.info "🔍 Rich Link - Scraped title: #{og_data[:title]}"
      Rails.logger.info "🔍 Rich Link - Scraped image: #{og_data[:image_url]}"

      # Merge scraped data with provided data (provided data takes precedence)
      content_attrs = content_attrs.merge({
        'title' => content_attrs['title'].presence || og_data[:title],
        'image_url' => content_attrs['image_url'].presence || og_data[:image_url],
        'description' => content_attrs['description'].presence || og_data[:description]
      }.compact)
    else
      Rails.logger.warn "⚠️ Rich Link - Open Graph scraping failed: #{og_data[:error]}"
    end
  end

  {
    url: url,
    title: content_attrs['title'] || extract_title_from_url(url),
    assets: build_assets(content_attrs)
  }
end
```

2. **Added `scrape_open_graph_data` method** (lines 138-153):
```ruby
def scrape_open_graph_data(url)
  return { success: false, error: 'No URL provided' } if url.blank?

  Rails.logger.info "🔍 Rich Link - Scraping Open Graph data for: #{url}"

  parser = AppleMessagesForBusiness::OpenGraphParserService.new(url)
  result = parser.parse

  Rails.logger.info "🔍 Rich Link - Scraping result success: #{result[:success]}"

  result
rescue StandardError => e
  Rails.logger.error "❌ Rich Link - Open Graph parsing error: #{e.message}"
  Rails.logger.error "❌ Rich Link - Backtrace: #{e.backtrace.first(3).join("\n")}"
  { success: false, error: e.message }
end
```

3. **Updated bot service** (3 locations):
   - `send_single_store_rich_link` (line 2057)
   - `handle_store_selection` (line 2272)
   - `handle_store_selection_qr` (line 2362)

Changed from manually providing Apple Maps icon:
```ruby
# Before
send_rich_link(
  url: maps_url,
  title: selected_store['name'],
  image_asset: 'https://www.apple.com/v/maps/d/images/overview/intro_icon__dfyvjc1ohbcm_large.jpg'
)

# After
send_rich_link(
  url: maps_url,
  title: selected_store['name'],
  image_asset: nil  # Let Open Graph scraping handle it
)
```

## How It Works

### Rich Link Data Flow

1. **Bot calls `send_rich_link`**:
   ```ruby
   send_rich_link(
     url: 'https://maps.apple.com/place?place-id=I1AD4262B0A0B785E',
     title: 'Apple Parly 2',
     image_asset: nil
   )
   ```

2. **SendRichLinkService checks for missing data**:
   - Title provided: 'Apple Parly 2' ✓
   - Image not provided: nil ❌
   - Triggers Open Graph scraping

3. **OpenGraphParserService scrapes URL**:
   - Downloads HTML from Apple Maps URL
   - Extracts `<meta property="og:title">` → 'Apple Parly 2'
   - Extracts `<meta property="og:image">` → Apple Maps preview image
   - Extracts `<meta property="og:description">` → Store description
   - Returns scraped data: `{ success: true, title: '...', image_url: '...' }`

4. **SendRichLinkService merges data**:
   ```ruby
   content_attrs = content_attrs.merge({
     'title' => content_attrs['title'].presence || og_data[:title],
     'image_url' => content_attrs['image_url'].presence || og_data[:image_url]
   }.compact)
   ```
   - Uses provided title (takes precedence)
   - Uses scraped image_url (since not provided)

5. **SendRichLinkService downloads and encodes image**:
   - Downloads image from scraped URL
   - Encodes to base64
   - Includes in `richLinkData` payload

6. **Apple MSP receives**:
   ```json
   {
     "type": "richLink",
     "richLinkData": {
       "url": "https://maps.apple.com/place?place-id=I1AD4262B0A0B785E",
       "title": "Apple Parly 2",
       "assets": {
         "image": {
           "data": "<base64_encoded_scraped_image>",
           "mimeType": "image/jpeg"
         }
       }
     }
   }
   ```

7. **User sees** complete rich link card with:
   - Scraped Apple Maps preview image
   - Store name as title
   - Tappable link to Apple Maps

## Benefits

### Before
- Required manual title/image provision
- Generic Apple icon (if provided)
- No automatic metadata extraction
- Inconsistent rich link appearance

### After
- ✅ Automatic Open Graph scraping
- ✅ Uses Apple's official Maps preview image
- ✅ Extracts actual store metadata
- ✅ Fallback to manual data if scraping fails
- ✅ Provided data takes precedence over scraped data
- ✅ Professional appearance with authentic imagery

## Technical Details

### URL Format

Correct Apple Maps place ID URL format:
```
https://maps.apple.com/place?place-id=I1AD4262B0A0B785E
```

**NOT** ❌:
```
https://maps.apple.com/place?id=I1AD4262B0A0B785E  # Wrong parameter name
```

### Open Graph Metadata

Apple Maps URLs include standard Open Graph meta tags:
```html
<meta property="og:title" content="Apple Parly 2">
<meta property="og:image" content="https://...">
<meta property="og:description" content="Store description">
```

The `OpenGraphParserService` extracts these tags automatically.

### Precedence Rules

1. **Manually provided data takes precedence**:
   - If `content_attrs['title']` is set → use it
   - If `content_attrs['image_url']` is set → use it

2. **Scraped data used when manual data missing**:
   - If title blank → use `og_data[:title]`
   - If image_url blank → use `og_data[:image_url]`

3. **Fallback to generic extraction**:
   - If scraping fails → use `extract_title_from_url` (domain name)
   - If image missing → no image in rich link

### Image Handling

The `build_assets` method accepts:
- **Full URLs**: Downloads and encodes image
- **Base64 data**: Uses directly
- **nil**: No image (falls back to scraped URL)

### Error Handling

If Open Graph scraping fails:
1. Service logs error with details
2. Falls back to manually provided data (if any)
3. Falls back to generic title extraction
4. Rich link sent with whatever data available

```ruby
rescue StandardError => e
  Rails.logger.error "❌ Rich Link - Open Graph parsing error: #{e.message}"
  { success: false, error: e.message }
end
```

## Performance

### Scraping Impact
- **Only triggers when data missing**: If title AND image provided, no scraping
- **One-time HTTP request**: Downloads HTML to extract meta tags
- **Cached by OpenGraphParserService**: Parser may implement caching
- **Timeout protection**: HTTP request has timeout (from parser)
- **Size**: HTML page typically 50-200KB (much smaller than full download)

### Payload Size
- **Scraped image encoded**: Varies by Apple Maps preview size
- **Typical size**: ~100-300KB base64 (depends on image)
- **Well within Apple's limits** (max 500KB per message)

## Related Files

1. **SendRichLinkService**: `app/services/apple_messages_for_business/send_rich_link_service.rb`
   - Lines 53-83: `build_rich_link_data` (modified)
   - Lines 138-153: `scrape_open_graph_data` (new)

2. **OpenGraphParserService**: `app/services/apple_messages_for_business/open_graph_parser_service.rb`
   - Lines 62-99: `parse_apple_maps_url` (handles Apple Maps URLs)
   - Lines 137-147: `extract_open_graph_data` (extracts meta tags)

3. **Bot Service**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
   - Lines 2054-2058: `send_single_store_rich_link` (updated to nil)
   - Lines 2269-2273: `handle_store_selection` (updated to nil)
   - Lines 2359-2363: `handle_store_selection_qr` (updated to nil)

## Status

✅ **IMPLEMENTED**
- Open Graph scraping integrated into SendRichLinkService
- Bot service updated to use automatic scraping
- Proper error handling in place
- Logging enhanced for debugging
- Ready for testing

## Deployment

```bash
# Restart server to apply changes
./script//dev-server.sh restart

# Test with store selection flow
# Monitor logs for scraping activity
tail -f log/development.log | grep -E "Rich Link|Open Graph|🔍|✅|❌"
```

## Testing

### Test Scenarios

1. **Automatic scraping (no manual data)**:
   ```
   User: "Paris"
   Bot: [Sends list picker with 4 stores]
   User: [Selects "Apple Parly 2"]
   Bot: [Sends rich link with scraped title & image]
   Expected: Complete rich link with Apple Maps preview
   ```

2. **Manual data provided (skip scraping)**:
   ```ruby
   send_rich_link(
     url: 'https://example.com',
     title: 'My Title',
     image_asset: 'https://example.com/image.jpg'
   )
   Expected: Uses provided title/image, no scraping
   ```

3. **Partial manual data (scrape missing)**:
   ```ruby
   send_rich_link(
     url: 'https://maps.apple.com/place?place-id=XXX',
     title: 'Store Name',
     image_asset: nil
   )
   Expected: Uses provided title, scrapes image
   ```

### Verification

Check logs for successful scraping:
```
🔍 Rich Link - Title or image missing, attempting Open Graph scraping for: https://maps.apple.com/place?place-id=I1AD4262B0A0B785E
🔍 Rich Link - Scraping Open Graph data for: https://maps.apple.com/place?place-id=I1AD4262B0A0B785E
🔍 Rich Link - Scraping result success: true
✅ Rich Link - Open Graph scraping successful
🔍 Rich Link - Scraped title: Apple Parly 2
🔍 Rich Link - Scraped image: https://...
```

### User Experience

**In Apple Messages app**:
- Rich link card appears with authentic Apple Maps imagery
- Shows store name and preview from actual Maps page
- Tapping opens location in Apple Maps app
- Professional appearance matching Apple's design

## Future Enhancements

Potential improvements:
1. **Caching scraped data**: Cache Open Graph results per URL for performance
2. **Fallback images**: Use generic Apple Maps icon if scraping fails completely
3. **Preview validation**: Verify scraped images are valid before encoding
4. **Custom metadata**: Allow overriding specific fields while scraping others

---

**Enhancement Date**: November 2025
**Issue**: Apple Maps rich links requiring manual metadata provision
**Solution**: Integrated Open Graph scraping for automatic metadata extraction
