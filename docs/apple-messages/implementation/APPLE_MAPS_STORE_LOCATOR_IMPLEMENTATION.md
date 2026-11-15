# Apple Maps Server API - Store Locator Implementation Plan

## Overview

This document outlines the implementation plan for integrating Apple Maps Server API into the Acoustic House Bot to find nearby Apple Stores based on user location. This enhancement will replace the current hardcoded location lookup with real-time Apple Store search using Apple's official mapping service.

## Current Implementation

### Location Flow (Lines 828-873 in `acoustic_house_bot_service.rb`)

**State AHF3** - `handle_location_request`:
- Asks user for zipcode
- Simple text-based request
- No actual location services

**State AHG1** - `handle_location_response`:
- Accepts zipcode or Apple Maps link
- Uses hardcoded `geocode_zipcode()` method
- Always falls back to Apple Park (zipcode 95014)
- No real Apple Store search capability

### Current Limitations

❌ **No Real Geocoding** - Hardcoded zipcode-to-coordinates mapping  
❌ **No Store Search** - Cannot find actual Apple Store locations  
❌ **Poor UX** - Always defaults to Apple Park regardless of user location  
❌ **No Distance Calculation** - Cannot show nearest stores  
❌ **Limited Coverage** - Only works for pre-defined zipcodes

## Proposed Solution: Apple Maps Server API Integration

### Why Apple Maps Server API?

✅ **Official Apple Service** - First-party integration with Apple ecosystem  
✅ **Global Coverage** - Worldwide geocoding and place search  
✅ **High Quality Data** - Accurate Apple Store locations and details  
✅ **Business-Friendly** - Designed for server-side business applications  
✅ **Reliable** - Enterprise-grade SLA and support

### API Capabilities

1. **Geocoding** - Convert addresses/zipcodes to coordinates
2. **Reverse Geocoding** - Convert coordinates to addresses
3. **Search** - Find places (Apple Stores) near coordinates
4. **Place Details** - Get store information (name, address, phone, hours)

## Implementation Phases

### Phase 1: Apple Maps Service Setup (Week 1)

#### Apple Developer Configuration

**Prerequisites:**
- Apple Developer Account with Team ID
- Maps Server API access enabled
- Private key for JWT signing (.p8 file)
- Key ID from Apple Developer Portal

**Environment Variables:**
```bash
APPLE_MAPS_TEAM_ID=your_team_id
APPLE_MAPS_KEY_ID=your_key_id
APPLE_MAPS_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----...-----END PRIVATE KEY-----
```

#### Create AppleMapsService

**File:** `app/services/apple_messages_for_business/apple_maps_service.rb`

**Key Features:**
- JWT token generation (ES256 algorithm)
- Geocoding API integration
- Place search with radius filtering
- Response caching (1 hour TTL)
- Comprehensive error handling

### Phase 2: Bot Service Integration (Week 2)

#### Enhanced Location Response Handler

**Updates to `handle_location_response`:**
1. Extract coordinates from user input (zipcode or Apple Maps link)
2. Search for nearby Apple Stores using Apple Maps API
3. Present results in List Picker format
4. Handle store selection
5. Fallback to Apple Park if no stores found

#### New Interactive Handler

**Add to INTERACTIVE_HANDLERS:**
```ruby
'lp_store_selection' => :handle_store_selection
```

**Store Selection Flow:**
1. User selects store from list
2. Extract store details
3. Send confirmation message
4. Proceed to time picker with selected store

### Phase 3: Enhanced Features (Week 3)

#### Store Details Integration
- Display store hours
- Show phone numbers
- Include addresses
- Add map preview links

#### Distance Calculation
- Haversine formula for accurate distances
- Sort stores by proximity
- Display distances in km/miles

#### Multi-Language Support
- Localized store names
- Translated UI elements
- Regional formatting

### Phase 4: Error Handling & Optimization (Week 4)

#### Comprehensive Error Handling
- Rate limit errors
- Authentication failures
- Network timeouts
- Invalid input handling
- Graceful fallbacks

#### Performance Optimization
- Redis caching layer
- Exponential backoff retry logic
- Batch request optimization
- Response time monitoring

## Technical Architecture

### Service Layer

```
AppleMapsService
├── generate_token() - JWT authentication
├── geocode(address) - Address to coordinates
├── reverse_geocode(lat, lon) - Coordinates to address
├── search_nearby(lat, lon, query, radius) - Find places
└── get_place_details(place_id) - Detailed information
```

### Bot Integration

```
handle_location_response()
├── get_coordinates_from_input()
├── search_nearby_stores()
├── send_store_selection_list_picker()
└── handle_store_selection()
```

### Data Flow

```
User Input → Geocoding → Store Search → List Picker → Selection → Time Picker
     ↓           ↓            ↓             ↓            ↓           ↓
  Validation  Caching    Filtering    Presentation  Storage   Confirmation
```

## API Integration Details

### Authentication

**JWT Token Structure:**
```json
{
  "iss": "TEAM_ID",
  "iat": 1234567890,
  "exp": 1234569690
}
```

**Signing:** ES256 algorithm with .p8 private key

### Geocoding Request

**Endpoint:** `POST https://maps-api.apple.com/v1/geocode`

**Request:**
```json
{
  "address": "94103"
}
```

**Response:**
```json
{
  "results": [{
    "coordinate": {
      "latitude": 37.7749,
      "longitude": -122.4194
    },
    "formattedAddress": "San Francisco, CA 94103"
  }]
}
```

### Search Request

**Endpoint:** `POST https://maps-api.apple.com/v1/search`

**Request:**
```json
{
  "q": "Apple Store",
  "searchLocation": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "searchRegion": {
    "radius": 50000
  }
}
```

**Response:**
```json
{
  "results": [{
    "name": "Apple Union Square",
    "coordinate": {
      "latitude": 37.7880,
      "longitude": -122.4074
    },
    "formattedAddress": "300 Post St, San Francisco, CA 94108",
    "phone": "+1 (415) 486-4800"
  }]
}
```

## Testing Strategy

### Unit Tests
- AppleMapsService methods
- Coordinate extraction
- Distance calculations
- Error handling

### Integration Tests
- Full location flow
- Store selection
- Fallback scenarios
- Cache behavior

### Manual Testing
- Various zipcodes
- International addresses
- Apple Maps links
- Edge cases

## Performance Metrics

### Target Metrics
- API Response Time: <500ms
- Total Flow Time: <2 seconds
- Cache Hit Rate: >90%
- Error Rate: <1%

### Monitoring
- API usage tracking
- Error rate alerts
- Response time monitoring
- Cache effectiveness

## Security Considerations

### API Key Security
- Encrypted environment variables
- Key rotation every 90 days
- Separate dev/prod keys
- Usage monitoring

### Data Privacy
- No permanent coordinate storage
- Session-based location data
- GDPR/CCPA compliance
- User opt-out mechanism

### Input Validation
- Sanitize user input
- Validate coordinate ranges
- Prevent injection attacks
- Rate limiting

## Cost Analysis

### API Pricing
- Free Tier: 25,000 requests/day
- Paid Tier: $0.50 per 1,000 requests
- Estimated Monthly Cost: $0-50

### ROI Benefits
- Improved user experience
- Global scalability
- Reduced support tickets
- Brand alignment with Apple

## Deployment Plan

### Pre-Deployment
1. Obtain API credentials
2. Configure environment
3. Test in staging
4. Set up monitoring

### Deployment
1. Deploy service layer
2. Enable feature flag
3. Monitor metrics
4. Gradual rollout

### Post-Deployment
1. Monitor API usage
2. Track success rates
3. Collect feedback
4. Optimize performance

## Success Criteria

### Technical Success
- ✅ API integration working
- ✅ Error rate <1%
- ✅ Response time <2s
- ✅ Cache hit rate >90%

### Business Success
- ✅ User satisfaction improved
- ✅ Store selection rate >80%
- ✅ Fallback rate <10%
- ✅ Global coverage achieved

## Future Enhancements

### Phase 5: Advanced Features
- Real-time store hours
- Appointment availability
- Service filtering
- Walking directions
- Transit integration
- Store photos
- Reviews integration

### Phase 6: Analytics
- Location heatmaps
- Popular stores tracking
- Search pattern analysis
- Conversion funnels
- A/B testing

## Documentation

### Files to Create
- `APPLE_MAPS_INTEGRATION.md` - Technical guide
- `STORE_LOCATOR_USER_GUIDE.md` - User documentation
- `TROUBLESHOOTING.md` - Common issues

### Files to Update
- `README.md` - Add integration section
- `AGENTS.md` - Update bot capabilities
- `DEPLOYMENT.md` - Add setup steps

## Timeline

**Week 1:** Apple Maps Service implementation  
**Week 2:** Bot integration and testing  
**Week 3:** Enhanced features and optimization  
**Week 4:** Error handling and deployment

**Total Duration:** 4 weeks  
**Resources Required:** 1 developer

## Conclusion

This implementation plan provides a comprehensive roadmap for integrating Apple Maps Server API into the Acoustic House Bot. The phased approach ensures minimal risk, high quality, and significant improvement to the user experience.

**Key Benefits:**
- ✅ Real-time Apple Store locations
- ✅ Global coverage
- ✅ Accurate distance calculations
- ✅ Improved user experience
- ✅ Scalable architecture

**Next Steps:**
1. Review and approve plan
2. Obtain Apple Maps API credentials
3. Begin Phase 1 implementation
4. Schedule progress reviews

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-17  
**Status:** Ready for Implementation