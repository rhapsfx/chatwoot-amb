# Guitar Information Collection Form Template

## Overview

This document describes the Guitar Information Collection Form template created for Chatwoot's Apple Messages for Business integration, based on the Acoustic House Bot's guitar form.

## Source

- **Original Bot**: Acoustic House Bot (`_apple/Acoustic-House-Bot-origin`)
- **Original Form**: `acoustichouse/json/en/as_order_form.json`
- **Creation Script**: `script/create_guitar_info_form_template.rb`

## Form Structure

The form collects comprehensive guitar information through 5 pages:

### Page 1: Guitar Model Selection
- **Type**: Select (single choice)
- **Title**: "Choose Your Guitar"
- **Subtitle**: "Select the guitar model you own or are interested in"
- **Options**:
  1. Gibson Les Paul R8 (with image)
  2. Martin DC28E Dreadnought (with image)
  3. Paul Reed Smith Custom (with image)

### Page 2: Customer Name
- **Type**: Text Input
- **Title**: "Your Name"
- **Subtitle**: "Please enter your full name"
- **Placeholder**: "John Doe"

### Page 3: Email Address
- **Type**: Text Input (Email keyboard)
- **Title**: "Email Address"
- **Subtitle**: "We'll send updates about your guitar"
- **Placeholder**: "john@example.com"
- **Keyboard**: Email-optimized

### Page 4: Serial Number
- **Type**: Text Input
- **Title**: "Serial Number"
- **Subtitle**: "Enter your guitar's serial number (if applicable)"
- **Placeholder**: "SN123456"

### Page 5: Purchase Date
- **Type**: Date Picker
- **Title**: "Purchase Date"
- **Subtitle**: "When did you purchase this guitar?"
- **Action**: Submit Form

## Images Required

The form requires the following images to be placed in `tmp/guitar_form_images/`:

1. **gibson_les_paul.png** - Image for Gibson Les Paul R8
2. **martin_dreadnought.png** - Image for Martin DC28E Dreadnought
3. **paul_reed_smith.png** - Image for Paul Reed Smith Custom
4. **guitar_collection_header.png** - Header image for messages

### Image Specifications
- **Format**: PNG
- **Recommended Size**: 512x512 pixels or larger
- **Purpose**: Display in Apple Messages for Business interactive messages

## Installation

### Prerequisites
1. Chatwoot installation with Apple Messages for Business configured
2. An active Apple Messages for Business inbox
3. Guitar images prepared in the correct directory

### Step 1: Prepare Images
```bash
mkdir -p tmp/guitar_form_images
# Copy your guitar images to this directory with the correct filenames
```

### Step 2: Run the Creation Script
```bash
rails runner script/create_guitar_info_form_template.rb \
  --account-id 1 \
  --inbox-id 2
```

Replace `1` with your Account ID and `2` with your Apple Messages for Business Inbox ID.

### Step 3: Verify Creation
The script will:
1. Upload all guitar images to Chatwoot
2. Create the form template
3. Associate it with your inbox
4. Output the template ID for future use

## Usage

### Via Bot API
```ruby
# Send the form to a customer
FormService.send_form(
  conversation: conversation,
  template_id: GUITAR_FORM_TEMPLATE_ID
)
```

### Via Frontend
1. Open a conversation in the Apple Messages for Business inbox
2. Click the "Forms" button in the composer
3. Search for "Guitar Information"
4. Select and send

## Data Collection

When a customer completes the form, Chatwoot will receive:

```json
{
  "001": {
    "items": [
      {
        "identifier": "001_01",
        "title": "Gibson Les Paul R8",
        "value": "Gibson Les Paul R8"
      }
    ]
  },
  "002": {
    "value": "John Doe"
  },
  "003": {
    "value": "john@example.com"
  },
  "004": {
    "value": "SN123456"
  },
  "005": {
    "value": "2024-01-15"
  }
}
```

## Processing Responses

The form responses can be processed using Chatwoot's webhook system or bot integration:

```ruby
# Example webhook handler
def handle_guitar_form_response(data)
  guitar_model = data['001']['items'].first['value']
  customer_name = data['002']['value']
  email = data['003']['value']
  serial_number = data['004']['value']
  purchase_date = data['005']['value']

  # Store in your database or CRM
  GuitarRegistration.create!(
    model: guitar_model,
    customer_name: customer_name,
    email: email,
    serial_number: serial_number,
    purchase_date: Date.parse(purchase_date)
  )
end
```

## Template Metadata

```yaml
Name: Guitar Information Collection Form
Category: general
Description: Collect detailed information about customer guitars
Supported Channels:
  - apple_messages_for_business
Use Cases:
  - bot_api_only
Tags:
  - guitar
  - information
  - form
  - customer_data
```

## Customization

### Changing Guitar Models
Edit the script at line ~110-145 to modify the guitar options:

```ruby
{
  'title' => 'Your Guitar Model',
  'value' => 'Your Guitar Model',
  'identifier' => '001_04',
  'image_identifier' => uploaded_images['your_guitar']&.[](:id)&.to_s,
  'next_page_identifier' => '002'
}
```

### Adding More Fields
Add new pages to the `pages` array:

```ruby
{
  'page_identifier' => '006',
  'type' => 'text',
  'title' => 'Additional Notes',
  'subtitle' => 'Any other information about your guitar',
  'submit_form' => true
}
```

### Field Types Available
- `select` - Multiple choice (single or multiple selection)
- `text` - Text input
- `date` - Date picker
- `time` - Time picker

## Troubleshooting

### Images Not Loading
1. Verify images exist in `tmp/guitar_form_images/`
2. Check file names match exactly (case-sensitive)
3. Ensure images are valid PNG format

### Form Not Sending
1. Verify the inbox is Apple Messages for Business type
2. Check that the template was created successfully
3. Confirm the customer is using an Apple device

### Data Not Received
1. Check webhook configuration
2. Verify bot integration is active
3. Review Chatwoot logs for errors

## Related Files

- Script: `script/create_guitar_info_form_template.rb`
- Original Form: `_apple/Acoustic-House-Bot-origin/acoustichouse/json/en/as_order_form.json`
- Reference Script: `script/create_aha19_menu_template.rb`
- Form Service: `app/services/apple_messages_for_business/form_service.rb`

## Technical Notes

### CaseTransformer Integration
The form automatically uses Chatwoot's `CaseTransformer` to handle field name conversions:
- **Internal storage**: snake_case (e.g., `image_identifier`)
- **Apple MSP API**: camelCase (e.g., `imageIdentifier`)

All case conversions are handled automatically by:
- `AppleMessagesForBusiness::CaseTransformer`
- `API::V1::Accounts::Messages::Create` (auto-normalization)

### Version Information
- **Apple Messages Form Version**: 1.2
- **Template Type**: `messageForms`
- **Created**: November 2025
- **Last Updated**: November 2025

## Support

For questions or issues:
1. Check the Apple Messages for Business documentation
2. Review `docs/apple-messages/` for case normalization guides
3. Consult `CLAUDE.md` for Chatwoot development guidelines
