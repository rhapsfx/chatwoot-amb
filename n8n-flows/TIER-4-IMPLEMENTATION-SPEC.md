# Tier 4 Advanced Features - Implementation Specification

## Overview

This document specifies the implementation of Tier 4 Advanced Features for the Acoustic House Bot n8n workflow, based on the original Python bot implementation (lines 1013-1190 for catchers, 380-402 for auth, 1324-1340 for stores, 404-645 for rich links).

---

## 4.1 State Catchers - Retry Logic for Stuck Users

### Purpose
Handle users who don't respond to interactive elements by implementing incremental prompting with retry counters.

### Python Reference
- **AHC1** (Lines 1013-1035): Guitar Picker Catcher
- **AHF1** (Lines 1097-1109): Apple Pay Catcher
- **AHH1** (Lines 1168-1190): Time Picker Catcher

### Implementation Strategy

#### Counter System
- Store retry count in `custom_attributes.retry_count`
- Increment on each repeated message to same state
- Reset counter when user successfully responds

#### AHC1 - Guitar Picker Catcher

**Node Flow**:
```
Check Guitar Selection State (IF)
  ↓
Get Retry Count (Code)
  ↓
Check Retry Threshold (Switch/Router)
  ├─ Count = 0-1: Wait for selection
  ├─ Count = 2: Send prompt "Looks like we're waiting for you to select a guitar..."
  ├─ Count = 3: Resend guitar list picker
  └─ Count >= 5: Auto-select "Martin DC28E Dreadnought" + force continue
```

**Python Logic** (Lines 1013-1035):
```python
def AHC1(usr):
    count = usr.lastMessage.count("+")
    if count == 2:
        sendMessage(AH_ID, usr.userId, "Looks like we're waiting for you to select a guitar...")
    elif count == 3:
        sendInteractive(AH_ID, usr.userId, "guitar_listpicker.json", usr.lang)
    elif count > 5:
        sendMessage(AH_ID, usr.userId, "Okay, we will just pretend you selected the Martin DC28E...")
        usr.selection = "Martin DC28E Dreadnought"
        requestIdGuitar(usr)
```

**n8n Implementation**:
- **Node 1**: Check if in `guitar_list` state
- **Node 2**: Get/increment retry count from custom_attributes
- **Node 3**: Switch/Router based on count:
  - **0-1**: No action (normal flow)
  - **2**: Send gentle prompt
  - **3**: Resend guitar list (Template 329)
  - **5+**: Auto-select + continue to guitar image

#### AHF1 - Apple Pay Catcher

**Node Flow**:
```
Check Apple Pay State (IF)
  ↓
Get Retry Count (Code)
  ↓
Check Retry Threshold (IF)
  ├─ Count <= 2: Wait for payment
  └─ Count > 2: Send "Just kidding {name}. No payment was processed." + Continue to lesson scheduling
```

**Python Logic** (Lines 1097-1109):
```python
def AHF1(usr):
    count = usr.lastMessage.count("+")
    if count > 2:
        sendMessage(AH_ID, usr.userId, f"Just kidding {row[1]}. No payment was processed.")
        if userStatus(usr.userId) != "stop":
            AHF2(usr)
```

**n8n Implementation**:
- **Node 1**: Check if in `payment_request` state
- **Node 2**: Get/increment retry count
- **Node 3**: IF count > 2:
  - Send "Just kidding" message
  - Continue to time picker (lesson scheduling)

#### AHH1 - Time Picker Catcher

**Node Flow**:
```
Check Time Picker State (IF)
  ↓
Get Retry Count (Code)
  ↓
Check Retry Threshold (Switch/Router)
  ├─ Count = 0-1: Wait for selection
  ├─ Count = 2: Send prompt "Looks like we're waiting for you to select a time..."
  ├─ Count = 3: Resend time picker
  └─ Count >= 5: Send "You must be a shredding pro, we can skip..." + Continue without lesson
```

**Python Logic** (Lines 1168-1190):
```python
def AHH1(usr):
    count = usr.lastMessage.count("+")
    if count == 2:
        sendMessage(AH_ID, usr.userId, "Looks like we're waiting for you to select a time...")
    elif count == 3:
        sendLocalTimePicker(...)
    elif count == 5:
        sendMessage(AH_ID, usr.userId, "You must be a shredding pro, we can skip...")
        AHH2(usr)
```

**n8n Implementation**:
- **Node 1**: Check if in `appointment_booking` state
- **Node 2**: Get/increment retry count
- **Node 3**: Switch/Router based on count:
  - **0-1**: No action
  - **2**: Send gentle prompt
  - **3**: Resend time picker (Template 5)
  - **5+**: Skip lesson + continue to next flow

### Custom Attributes Schema

```javascript
custom_attributes: {
  bot_state: "guitar_list" | "payment_request" | "appointment_booking",
  retry_count: 0,  // Incremented on each repeated state
  last_state_change: "2025-01-10T12:00:00Z"
}
```

---

## 4.2 Authentication Flows - OAuth Placeholders

### Purpose
Demonstrate authentication capabilities (LinkedIn, native auth, server-side auth) with placeholder implementations.

### Python Reference
- **requestIdAuth** (Lines 808-817): LinkedIn OAuth response handler
- **send_native_auth** (Lines 387-390): Native auth initiation
- **serverSideResponse** (Lines 829-839): Server-side auth completion
- **sendAuthStatus** (Lines 841-845): Auth status display

### Implementation Strategy

#### LinkedIn OAuth Flow (Placeholder)

**Node Flow**:
```
"authenticate" keyword received
  ↓
Send OAuth Explanation Message
  ↓
Send List Picker: "LinkedIn OAuth" (Placeholder)
  ↓
[User selection triggers OAuth - PLACEHOLDER]
  ↓
Display Placeholder Success Message: "LinkedIn OAuth would connect here. Real implementation requires OAuth server."
```

**Python Logic** (Lines 808-817):
```python
def requestIdAuth(usr):
    selection = json.loads(usr.selection[0]["oauth"])
    sendMessage(AH_ID, usr.userId, f"Hey {selection['displayName']}, nice to see you.")
    # ... store user data
```

**n8n Implementation**:
- **Node 1**: Detect "authenticate" keyword
- **Node 2**: Send explanation: "This demo would connect to LinkedIn OAuth. Real implementation requires OAuth server setup."
- **Node 3**: Send List Picker with placeholder options:
  - "LinkedIn OAuth (Placeholder)"
  - "Native Auth (Placeholder)"
  - "Server-Side Auth (Placeholder)"
- **Node 4**: On selection → Display TODO message with OAuth URL format

#### Native Auth (Placeholder)

**Python Logic** (Lines 387-390):
```python
def send_native_auth(usr):
    sendInteractive(AH_ID, usr.userId, "native_auth.json", usr.lang)
```

**n8n Implementation**:
- Send message: "Native authentication would be triggered here with Apple's auth framework."
- Display: "In production, this would open native iOS authentication."

#### Server-Side Auth (Placeholder)

**Python Logic** (Lines 829-839):
```python
def serverSideResponse(usr):
    # Retrieve stored auth data
    sendMessage(AH_ID, usr.userId, f"Welcome back, {userData['name']}")
```

**n8n Implementation**:
- Send message: "Server-side authentication complete (simulated)."
- Display placeholder user data: "Name: Demo User, Status: Authenticated"

### TODO Documentation

Add comment node:
```
TODO - Authentication Implementation:

1. LinkedIn OAuth:
   - Setup OAuth app at https://www.linkedin.com/developers/
   - Implement OAuth callback handler
   - Store access tokens securely
   - Exchange for user profile data

2. Native Auth:
   - Requires Apple Messages for Business native auth capability
   - Configure in Business Chat account
   - Handle auth tokens in backend

3. Server-Side Auth:
   - Setup auth server endpoint
   - Implement token exchange
   - Store user session data
   - Provide auth status API

External Services Required:
- OAuth provider (LinkedIn, etc.)
- Auth token storage (Redis/Database)
- Backend auth API
```

---

## 4.3 Store Locator System

### Purpose
Find and display nearest stores based on user location (zipcode or Apple Maps link).

### Python Reference
- **AHG1** (Lines 1130-1166): Location processing and geocoding
- **findStores** (Lines 1324-1340): KDTree spatial search for nearest stores
- **requestGeoCode** (Lines 737-746): Geocode selection handler
- **requestStore** (Lines 748-754): Store selection handler

### Implementation Strategy

#### Simplified Implementation (Hardcoded Stores)

**Node Flow**:
```
User sends zipcode/location
  ↓
Geocoding Placeholder (Code Node)
  ├─ Parse zipcode (e.g., "94102")
  ├─ Return hardcoded coordinates: { lat: 37.7749, lng: -122.4194 }
  └─ Return 5 nearest stores (hardcoded list)
  ↓
Build Store List Picker
  ↓
Send Store List Picker (AMB List Picker)
  ↓
User selects store
  ↓
Send Time Picker for selected store
```

**Python Logic** (Lines 1324-1340):
```python
def findStores(usr):
    storeList = []
    # KDTree.query to find 5 nearest stores
    for i in nearest_indices:
        storeList.append({
            'name': stores[i].name,
            'address': stores[i].address,
            'distance': distance
        })
    # Send store list picker
```

**n8n Implementation**:

**Node 1: Geocoding Placeholder (Code)**
```javascript
// Placeholder geocoding logic
const input = $json.rawContent; // User's zipcode/location
let coordinates = { lat: 37.7749, lng: -122.4194 }; // SF default

// Hardcoded zipcode mapping
const zipcodeMap = {
  '94102': { lat: 37.7749, lng: -122.4194, city: 'San Francisco' },
  '10001': { lat: 40.7506, lng: -73.9971, city: 'New York' },
  '90210': { lat: 34.0901, lng: -118.4065, city: 'Beverly Hills' },
  '60601': { lat: 41.8858, lng: -87.6229, city: 'Chicago' },
  '98101': { lat: 47.6097, lng: -122.3331, city: 'Seattle' }
};

if (zipcodeMap[input]) {
  coordinates = zipcodeMap[input];
}

// Hardcoded store list (5 nearest)
const stores = [
  {
    identifier: 'store_sf_union',
    title: 'Acoustic House - Union Square',
    subtitle: '300 Post St, San Francisco, CA 94108 (0.8 miles)',
    distance: 0.8
  },
  {
    identifier: 'store_sf_soma',
    title: 'Acoustic House - SOMA',
    subtitle: '123 Townsend St, San Francisco, CA 94107 (1.2 miles)',
    distance: 1.2
  },
  {
    identifier: 'store_sf_marina',
    title: 'Acoustic House - Marina',
    subtitle: '2100 Chestnut St, San Francisco, CA 94123 (2.5 miles)',
    distance: 2.5
  },
  {
    identifier: 'store_sf_mission',
    title: 'Acoustic House - Mission',
    subtitle: '3045 24th St, San Francisco, CA 94110 (3.1 miles)',
    distance: 3.1
  },
  {
    identifier: 'store_oakland',
    title: 'Acoustic House - Oakland',
    subtitle: '1111 Broadway, Oakland, CA 94607 (12.5 miles)',
    distance: 12.5
  }
];

return {
  json: {
    coordinates: coordinates,
    stores: stores,
    conversationId: $json.conversationId,
    accountId: $json.accountId
  }
};
```

**Node 2: Build Store List Picker (Code)**
```javascript
const stores = $json.stores || [];

const sections = [{
  title: 'Stores Near You',
  multipleSelection: false,
  items: stores.map(store => ({
    identifier: store.identifier,
    title: store.title,
    subtitle: store.subtitle,
    style: 'large'
  }))
}];

return {
  json: {
    sections: sections,
    conversationId: $json.conversationId,
    accountId: $json.accountId
  }
};
```

**Node 3: Send Store List Picker (AMB List Picker)**
- Template ID: Create new template for store list
- Dynamic sections from previous node

**Node 4: Parse Store Selection (Code)**
```javascript
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const interactive = contentAttrs.interactive_data?.data?.['list-picker'] || {};
const selected = interactive.selectedItems?.[0] || {};

const storeIdentifier = selected.identifier || '';
const storeTitle = selected.title || '';

return {
  json: {
    storeIdentifier: storeIdentifier,
    storeTitle: storeTitle,
    conversationId: data.conversation?.id,
    accountId: data.account?.id || 1
  }
};
```

**Node 5: Send Time Picker for Store**
- AMB Time Picker (Template 5)
- Customized with store name

### TODO Documentation

Add comment node:
```
TODO - Store Locator Full Implementation:

1. Geocoding Service Integration:
   - Google Maps Geocoding API
   - Apple Maps Geocoding
   - OpenStreetMap Nominatim
   - Handle multiple results (disambiguation)

2. Store Database:
   - Setup store database with coordinates
   - Store fields: name, address, lat, lng, phone, hours
   - Keep updated with real store locations

3. Spatial Search:
   - Implement KDTree or spatial index
   - Calculate distance (haversine formula)
   - Return N nearest stores
   - Sort by distance

4. Apple Maps Link Parsing:
   - Parse "maps.apple.com" links
   - Extract lat/lng from URL parameters
   - Handle Apple Maps place IDs

External Services Required:
- Geocoding API (Google/Apple/OSM)
- Store database (PostgreSQL with PostGIS)
- Spatial search library
```

---

## 4.4 Rich Link Features

### Purpose
Send rich links with preview cards (maps, websites, App Clips).

### Python Reference
- **AHI2** (Lines 1218-1224): Send rich link example
- **AHK3** (Lines 1296-1302): Final rich link
- **richlinkSQA** (Lines 698-704): Rich link demo
- **micro_*** (Lines 404-472): Rich link microservice

### Implementation Strategy

#### Rich Link Types

1. **Website Rich Link**
   - URL with preview card
   - Title, subtitle, image

2. **Maps Rich Link**
   - Apple Maps location
   - Address, business name

3. **App Clip Rich Link**
   - Invocation URL
   - App Clip metadata

#### Simplified Implementation

**Node Flow**:
```
"rich link" keyword received
  ↓
Send Website Rich Link (Placeholder)
  ↓
Send Maps Rich Link (Placeholder)
  ↓
Send App Clip Link (Placeholder)
  ↓
Display TODO: "Rich link microservice integration required"
```

**Python Logic** (Lines 1218-1224):
```python
def AHI2(usr):
    sendRichlink(AH_ID, usr.userId,
        "https://register.apple.com/resources/messages/...",
        "heroImage.png",
        "Apple Messages for Business")
```

**n8n Implementation**:

**Node 1: Send Website Rich Link (HTTP Request)**
```json
{
  "method": "POST",
  "url": "https://app.chatwoot.com/api/v1/accounts/{{accountId}}/conversations/{{conversationId}}/messages",
  "body": {
    "content": "Check out this website:\nhttps://register.apple.com/business-chat",
    "message_type": "outgoing"
  }
}
```

**Node 2: Send Maps Rich Link (HTTP Request)**
```json
{
  "method": "POST",
  "url": "https://app.chatwoot.com/api/v1/accounts/{{accountId}}/conversations/{{conversationId}}/messages",
  "body": {
    "content": "Visit our store:\nhttps://maps.apple.com/?address=300+Post+St,San+Francisco,CA",
    "message_type": "outgoing"
  }
}
```

**Node 3: Send App Clip Link (HTTP Request)**
```json
{
  "method": "POST",
  "url": "https://app.chatwoot.com/api/v1/accounts/{{accountId}}/conversations/{{conversationId}}/messages",
  "body": {
    "content": "Try our App Clip:\nhttps://acoustichouse.example.com/clip (Placeholder - requires App Clip setup)",
    "message_type": "outgoing"
  }
}
```

### TODO Documentation

Add comment node:
```
TODO - Rich Link Full Implementation:

1. Rich Link Microservice:
   - Setup rich link metadata generator
   - Scrape URL for og:title, og:image, og:description
   - Cache metadata for performance
   - Serve via API endpoint

2. Maps Rich Links:
   - Generate Apple Maps URLs with place IDs
   - Include business metadata
   - Handle region-specific links

3. App Clip Links:
   - Register App Clip with Apple
   - Configure invocation URLs
   - Setup App Clip experience
   - Handle universal links

4. Rich Media:
   - Image hosting for hero images
   - Video support for rich links
   - Fallback for unsupported clients

External Services Required:
- Rich link microservice (Python/Node.js)
- Metadata scraper (Open Graph)
- App Clip hosting (Xcode Cloud)
- CDN for media assets
```

---

## 4.5 Special Integrations

### Purpose
Placeholder implementations for advanced features (Shopify, BIA, CSAT, iMessage extensions).

### Python Reference
- **menu_shopify** (Lines 283-288): Shopify integration
- **send_bia** (Lines 497-512): Business Initiated Auth
- **send_csat** (Lines 907-910): CSAT survey
- **receivediMessageApp** (Lines 723-727): iMessage app integration

### Implementation Strategy

#### Shopify Integration (Placeholder)

**Node Flow**:
```
"shopify" keyword received
  ↓
Send Explanation Message
  ↓
Display TODO: "Shopify integration requires Shopify API setup"
```

**Python Logic** (Lines 283-288):
```python
def menu_shopify(usr):
    sendMessage(AH_ID, usr.userId, "Welcome to the Shopify integration...")
    # ... Shopify API calls
```

**n8n Implementation**:
- Send message: "Shopify integration would display products here."
- Display: "TODO: Requires Shopify API credentials and product sync."

#### Business Initiated Auth (BIA) (Placeholder)

**Python Logic** (Lines 497-512):
```python
def send_bia(usr):
    # Send BIA request
    data = {
        "requestIdentifier": "form_bia_ah",
        "responseEncryptionKey": key
    }
```

**n8n Implementation**:
- Send message: "Business Initiated Auth would request authentication here."
- Display: "TODO: Requires BIA credentials and encryption key setup."

#### CSAT Survey (Placeholder)

**Python Logic** (Lines 907-910):
```python
def send_csat(usr):
    sendInteractive(AH_ID, usr.userId, "csat.json", usr.lang)
```

**n8n Implementation**:
- Send message: "How would you rate your experience? (1-5 stars)"
- Send Quick Reply with 5 options
- Store response in custom_attributes.csat_rating

#### iMessage Extension (Placeholder)

**Python Logic** (Lines 723-727):
```python
def receivediMessageApp(usr):
    sendMessage(AH_ID, usr.userId, "Try our Shazam integration!")
    # Send iMessage app bubble
```

**n8n Implementation**:
- Send message: "iMessage apps and extensions would be triggered here."
- Display: "TODO: Requires iMessage app development and MSP configuration."

### TODO Documentation

Add comment node:
```
TODO - Special Integrations:

1. Shopify:
   - Setup Shopify API credentials
   - Implement product sync
   - Handle cart and checkout
   - Webhook integration for order updates

2. Business Initiated Auth (BIA):
   - Register BIA credentials with Apple
   - Setup encryption keys
   - Implement OAuth flow
   - Handle auth responses

3. CSAT Survey:
   - Design survey questions
   - Store responses in database
   - Analytics dashboard for ratings
   - Follow-up actions based on score

4. iMessage Extensions:
   - Develop iMessage app (Xcode)
   - Configure MSP for app bubbles
   - Handle interactive app data
   - Test on iOS devices

External Services Required:
- Shopify API and store setup
- Apple BIA registration
- Survey database and analytics
- iMessage app development environment
```

---

## Implementation Summary

### Node Count Estimate

| Feature Category | Nodes Required | Complexity |
|------------------|----------------|------------|
| **State Catchers** | 15-20 nodes | Medium |
| **Authentication Placeholders** | 8-10 nodes | Low |
| **Store Locator** | 10-12 nodes | Medium |
| **Rich Links** | 6-8 nodes | Low |
| **Special Integrations** | 8-10 nodes | Low |
| **TODO Documentation** | 5 comment nodes | Low |
| **Total** | **52-65 nodes** | **Medium** |

### Priority Implementation Order

1. **State Catchers** (Highest Priority)
   - Improves user experience significantly
   - Prevents users from getting stuck
   - Relatively simple to implement

2. **Store Locator** (High Priority)
   - Core feature for location-based services
   - Demonstrates spatial search capability
   - Hardcoded version is acceptable for demo

3. **Authentication Placeholders** (Medium Priority)
   - Shows OAuth capability
   - Simple placeholder implementation
   - Document full implementation requirements

4. **Rich Links** (Medium Priority)
   - Enhances visual experience
   - Simple URL-based implementation
   - Placeholder for microservice

5. **Special Integrations** (Low Priority)
   - Advanced features
   - Placeholder only for demo
   - Requires external services

### Custom Attributes Schema (Extended)

```javascript
custom_attributes: {
  // Existing
  bot_state: "string",
  user_name: "string",
  stage_name: "string",
  selected_name: "string",
  guitar_selection: "string",

  // Tier 4 additions
  retry_count: 0,
  last_state_change: "2025-01-10T12:00:00Z",
  auto_selected: false,
  store_selection: "string",
  store_coordinates: { lat: 0, lng: 0 },
  auth_status: "none" | "pending" | "authenticated",
  csat_rating: 0
}
```

### Testing Checklist

- [ ] Guitar Picker Catcher: User doesn't select guitar
  - [ ] 2nd message: Prompt sent
  - [ ] 3rd message: Guitar list resent
  - [ ] 5th message: Auto-select + continue

- [ ] Apple Pay Catcher: User doesn't pay
  - [ ] 3rd message: "Just kidding" + continue

- [ ] Time Picker Catcher: User doesn't select time
  - [ ] 2nd message: Prompt sent
  - [ ] 3rd message: Time picker resent
  - [ ] 5th message: Skip lesson + continue

- [ ] Authentication Placeholder
  - [ ] Keyword "authenticate" triggers flow
  - [ ] Explanation message displayed
  - [ ] TODO documentation shown

- [ ] Store Locator
  - [ ] Zipcode "94102" returns 5 stores
  - [ ] Store selection triggers time picker
  - [ ] Hardcoded stores displayed correctly

- [ ] Rich Links
  - [ ] Website link sent
  - [ ] Maps link sent
  - [ ] App Clip placeholder sent

- [ ] Special Integrations
  - [ ] Shopify placeholder shown
  - [ ] BIA placeholder shown
  - [ ] CSAT survey functional
  - [ ] iMessage extension placeholder shown

---

## File Deliverables

1. **Updated Workflow**: `Acoustic-House-Bot-MIGRATED.json`
2. **Implementation Guide**: `TIER-4-IMPLEMENTATION-GUIDE.md`
3. **TODO List**: `TIER-4-TODOS.md`
4. **Testing Guide**: `TIER-4-TESTING-GUIDE.md`

---

## External Dependencies Summary

### Required for Full Implementation:

1. **Geocoding Service**
   - Google Maps Geocoding API
   - Or Apple Maps Server API
   - Or OpenStreetMap Nominatim

2. **Store Database**
   - PostgreSQL with PostGIS extension
   - Store table with spatial index

3. **OAuth Provider**
   - LinkedIn OAuth app
   - Or other OAuth 2.0 provider

4. **Rich Link Microservice**
   - Metadata scraper
   - Image hosting
   - API endpoint

5. **Shopify Integration**
   - Shopify API credentials
   - Product sync webhook

6. **Apple Registrations**
   - Business Initiated Auth credentials
   - App Clip registration
   - iMessage app registration

### Acceptable for Demo/Placeholder:

- Hardcoded store list
- Simulated OAuth responses
- URL-only rich links
- Placeholder messages for integrations

---

## Conclusion

This specification provides a complete blueprint for implementing Tier 4 Advanced Features with a pragmatic approach:

- **State Catchers**: Fully implemented (improve UX)
- **Store Locator**: Simplified hardcoded version (demonstrate capability)
- **Authentication**: Placeholder with full documentation (show potential)
- **Rich Links**: Simple URL implementation (functional demo)
- **Special Integrations**: Placeholders only (acknowledge complexity)

The implementation balances demonstration value with development effort, providing a complete showcase of Apple Messages for Business capabilities while clearly documenting requirements for production deployment.
