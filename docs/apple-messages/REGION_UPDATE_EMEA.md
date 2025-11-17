# Region Selection Update: Europe → EMEA

## Overview

Updated region selection to be more geographically inclusive by changing "Europe" to "EMEA" (Europe, Middle East, and Africa).

## What Changed

### Before
- Region options: **Americas**, **Europe**, **Asia Pacific**

### After
- Region options: **Americas**, **EMEA**, **Asia Pacific**

## Why This Change?

**EMEA** (Europe, Middle East, and Africa) is a more inclusive designation that:
- Includes Middle Eastern countries (UAE, Saudi Arabia, Israel, etc.)
- Includes African countries (South Africa, Egypt, Morocco, etc.)
- Better reflects Apple's actual retail presence in these regions
- Aligns with standard business regional designations

### Apple Stores Covered by EMEA

**Europe:**
- UK (London, Glasgow, Edinburgh, etc.)
- France (Paris, Lyon, Marseille, etc.)
- Germany (Berlin, Munich, Frankfurt, etc.)
- Italy (Rome, Milan, Florence, etc.)
- Spain (Madrid, Barcelona, Valencia, etc.)
- Netherlands, Belgium, Sweden, Switzerland, etc.

**Middle East:**
- UAE (Dubai, Abu Dhabi)
- Saudi Arabia (Riyadh, Jeddah)
- Turkey (Istanbul)
- Israel (Tel Aviv)

**Africa:**
- South Africa (coming soon)

## Technical Changes

### 1. Bot Service Quick Reply Options
**File:** `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Line 346:**
```ruby
# Before
{ title: 'Europe', value: 'Europe' }

# After
{ title: 'EMEA', value: 'EMEA' }
```

### 2. NSKeyedArchiver Region Matching
**File:** `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Line 362:**
```ruby
# Before
region_name = objects.find { |obj| obj.is_a?(String) && obj.match?(/Americas|Europe|Asia Pacific/i) }

# After
region_name = objects.find { |obj| obj.is_a?(String) && obj.match?(/Americas|EMEA|Asia Pacific/i) }
```

### 3. Documentation Updates
**File:** `docs/apple-messages/GLOBAL_STORE_SEARCH.md`

- Line 36: Updated user flow description
- Line 65: Updated Scenario 2 example

## User Experience

### What Users See

When prompted "Where are you located?", users now see:
- **Americas** (North, Central, and South America)
- **EMEA** (Europe, Middle East, and Africa)
- **Asia Pacific** (Asia, Australia, Pacific Islands)

### Example Flow

1. **User selects:** "EMEA"
2. **Bot responds:** "Great! You selected EMEA."
3. **User provides location:**
   - Dubai postcode → Finds Apple Dubai Mall, Apple Mall of Emirates
   - London postcode → Finds Apple Regent Street, Apple Covent Garden
   - Paris postcode → Finds Apple Champs-Élysées, Apple Opéra

## Testing

The region selection change doesn't affect the actual store search logic (which is coordinate-based and global), but it provides better regional context for users.

### Test Scenarios

**Middle East User:**
```
User: [Selects EMEA]
Bot: "Great! You selected EMEA."
User: "Dubai Marina" or "Business Bay, Dubai"
Bot: [Geocodes → finds Dubai stores]
```

**African User (Future):**
```
User: [Selects EMEA]
Bot: "Great! You selected EMEA."
User: "Sandton, Johannesburg"
Bot: [Geocodes → finds South African stores when available]
```

## Backward Compatibility

This change is **non-breaking**:
- Old conversations with "Europe" stored in attributes will still work
- New conversations will use "EMEA"
- Search logic remains unchanged (coordinate-based, global)

## Related Documentation

- [Global Store Search](GLOBAL_STORE_SEARCH.md)
- [Apple Maps Store Locator Implementation](implementation/APPLE_MAPS_STORE_LOCATOR_IMPLEMENTATION.md)
- [Bot Service Overview](README_BOT_SERVICE.md)

## Status

✅ **IMPLEMENTED**
- Code updated in `acoustic_house_bot_service.rb`
- Documentation updated
- Ready for testing and deployment

## Geographic Coverage

### Region Breakdown

| Region | Countries Covered | Example Cities with Apple Stores |
|--------|-------------------|----------------------------------|
| **Americas** | USA, Canada, Mexico, Brazil | New York, Toronto, Mexico City, São Paulo |
| **EMEA** | Europe, Middle East, Africa | London, Paris, Dubai, Istanbul |
| **Asia Pacific** | Japan, China, Australia, Singapore, India | Tokyo, Beijing, Sydney, Singapore, Mumbai |

This provides balanced global coverage and aligns with international business standards.
