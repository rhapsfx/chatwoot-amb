# Tier 4 Advanced Features - TODO List

## Production Implementation Checklist

### Priority 1: State Catchers (READY)

#### AHC1 - Guitar Picker Catcher
- [x] Implement retry counter logic
- [x] Add gentle prompts (count = 2)
- [x] Add resend logic (count = 3)
- [x] Add auto-selection (count >= 5)
- [ ] Tune retry thresholds based on analytics
- [ ] Add logging for retry events
- [ ] Test with real users

#### AHF1 - Apple Pay Catcher
- [x] Implement retry counter logic
- [x] Add skip payment logic (count > 2)
- [x] Personalize skip message with user name
- [ ] Tune skip threshold based on analytics
- [ ] Add logging for skip events
- [ ] Test with real users

#### AHH1 - Time Picker Catcher
- [x] Implement retry counter logic
- [x] Add gentle prompts (count = 2)
- [x] Add resend logic (count = 3)
- [x] Add skip lesson logic (count >= 5)
- [ ] Tune retry thresholds based on analytics
- [ ] Add logging for retry events
- [ ] Test with real users

**Estimated Effort**: 1-2 days (tuning + analytics integration)

---

### Priority 2: Store Locator (REQUIRES EXTERNAL SERVICES)

#### Geocoding Service Integration
- [ ] **Choose geocoding provider**:
  - Option A: Google Maps Geocoding API ($5/1000 requests)
  - Option B: Apple MapKit Server API (Requires Apple Developer account)
  - Option C: OpenStreetMap Nominatim (Free, rate-limited)
- [ ] Setup API credentials
- [ ] Implement geocoding API calls
- [ ] Handle multiple geocoding results (disambiguation)
- [ ] Parse Apple Maps links (format: `maps.apple.com/?ll=lat,lng`)
- [ ] Add error handling for invalid locations
- [ ] Test with various input formats (zipcode, address, city, maps link)

#### Store Database Setup
- [ ] **Design store database schema**:
  ```sql
  CREATE TABLE stores (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zipcode VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    phone VARCHAR(20),
    hours JSONB,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
  );

  -- Add spatial index for PostGIS
  CREATE INDEX stores_location_idx ON stores
  USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));
  ```
- [ ] Populate with real store locations
- [ ] Setup PostGIS extension for spatial queries
- [ ] Create API endpoint for store search

#### Spatial Search Implementation
- [ ] **Option A: PostGIS (Recommended)**
  ```sql
  -- Find 5 nearest stores
  SELECT
    id, name, address,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint($user_lng, $user_lat), 4326)::geography
    ) / 1609.34 AS distance_miles
  FROM stores
  WHERE active = true
  ORDER BY distance_miles
  LIMIT 5;
  ```
- [ ] **Option B: KDTree (Python)**
  ```python
  from scipy.spatial import KDTree
  import numpy as np

  # Build tree from store coordinates
  store_coords = np.array([[store.lat, store.lng] for store in stores])
  tree = KDTree(store_coords)

  # Query nearest 5 stores
  distances, indices = tree.query([user_lat, user_lng], k=5)
  ```
- [ ] Replace hardcoded store list in `store-locator-geocode` node
- [ ] Update store list picker to use dynamic data
- [ ] Add distance calculation (haversine formula)
- [ ] Sort stores by distance
- [ ] Test with various locations

#### n8n Integration
- [ ] Create HTTP Request node for geocoding API
- [ ] Create HTTP Request node for store search API
- [ ] Update `store-locator-geocode` node to call APIs
- [ ] Add error handling for API failures
- [ ] Add caching for geocoding results (Redis)
- [ ] Test complete flow

**Estimated Effort**: 3-5 days (API setup + database + testing)

---

### Priority 3: Authentication (REQUIRES OAUTH SETUP)

#### LinkedIn OAuth Integration
- [ ] **Register OAuth app** at https://www.linkedin.com/developers/
- [ ] Get OAuth credentials (Client ID, Client Secret)
- [ ] Setup OAuth callback URL (e.g., `https://yourdomain.com/auth/linkedin/callback`)
- [ ] Implement OAuth flow:
  ```javascript
  // Step 1: Generate auth URL
  const authUrl = `https://www.linkedin.com/oauth/v2/authorization?` +
    `response_type=code&` +
    `client_id=${CLIENT_ID}&` +
    `redirect_uri=${REDIRECT_URI}&` +
    `scope=r_liteprofile%20r_emailaddress`;

  // Step 2: Handle callback, exchange code for token
  const tokenResponse = await fetch('https://www.linkedin.com/oauth/v2/accessToken', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: authCode,
      redirect_uri: REDIRECT_URI,
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET
    })
  });

  // Step 3: Get user profile
  const profileResponse = await fetch('https://api.linkedin.com/v2/me', {
    headers: { Authorization: `Bearer ${accessToken}` }
  });
  ```
- [ ] Store access tokens securely (Redis or database)
- [ ] Implement token refresh logic
- [ ] Add token expiration handling
- [ ] Update `auth-parse-selection` node to trigger real OAuth
- [ ] Test OAuth flow end-to-end

#### Native Auth (Apple Messages for Business)
- [ ] **Register for native auth** with Apple Business Chat
- [ ] Get native auth credentials
- [ ] Configure auth capabilities in Business Chat account
- [ ] Implement native auth JSON format:
  ```json
  {
    "receivedMessage": {
      "style": "icon",
      "title": "Sign in to continue"
    },
    "replyMessage": {
      "style": "icon",
      "title": "You're signed in!"
    },
    "oauth": {
      "responseEncryptionKey": "BASE64_PUBLIC_KEY",
      "clientId": "YOUR_CLIENT_ID",
      "scopes": ["profile", "email"]
    }
  }
  ```
- [ ] Handle auth tokens in backend
- [ ] Test on iOS devices

#### Server-Side Auth
- [ ] Setup auth server endpoint (e.g., `/api/auth/verify`)
- [ ] Implement token generation
- [ ] Implement session management
- [ ] Store user auth status in database
- [ ] Provide auth status API
- [ ] Update workflow to call auth API
- [ ] Test server-side auth flow

**Estimated Effort**: 5-7 days (OAuth setup + backend + testing)

---

### Priority 4: Rich Links (REQUIRES MICROSERVICE)

#### Rich Link Microservice
- [ ] **Setup rich link scraper service**:
  ```javascript
  // Example: Node.js/Express microservice
  const express = require('express');
  const axios = require('axios');
  const cheerio = require('cheerio');

  app.get('/api/richlink', async (req, res) => {
    const url = req.query.url;
    const html = await axios.get(url);
    const $ = cheerio.load(html.data);

    const metadata = {
      title: $('meta[property="og:title"]').attr('content'),
      description: $('meta[property="og:description"]').attr('content'),
      image: $('meta[property="og:image"]').attr('content'),
      url: url
    };

    res.json(metadata);
  });
  ```
- [ ] Deploy microservice (Heroku, AWS Lambda, Vercel)
- [ ] Add caching layer (Redis, 24hr TTL)
- [ ] Implement rate limiting
- [ ] Add error handling for invalid URLs

#### Maps Rich Links
- [ ] Generate Apple Maps URLs with place IDs
- [ ] Include business metadata (name, address, phone)
- [ ] Handle region-specific links (US, UK, etc.)
- [ ] Test maps links on iOS devices

#### App Clip Links
- [ ] **Register App Clip** with Apple
  - Developer account required
  - Xcode 12+ required
- [ ] Configure invocation URLs
- [ ] Setup App Clip experience (UI/UX)
- [ ] Handle universal links
- [ ] Test App Clip on iOS devices

#### n8n Integration
- [ ] Update `rich-link-website` to call microservice
- [ ] Format rich link response for Apple Messages
- [ ] Add fallback for scraping failures
- [ ] Test rich link rendering in Messages app

**Estimated Effort**: 4-6 days (microservice + App Clip + testing)

---

### Priority 5: Special Integrations (EXTERNAL SERVICES)

#### Shopify Integration
- [ ] **Setup Shopify Partner account** at https://partners.shopify.com/
- [ ] Create Shopify app
- [ ] Get API credentials (API key, API secret)
- [ ] Implement Shopify API integration:
  ```javascript
  // Fetch products
  const products = await fetch(
    `https://${SHOP_NAME}.myshopify.com/admin/api/2024-01/products.json`,
    { headers: { 'X-Shopify-Access-Token': ACCESS_TOKEN } }
  );
  ```
- [ ] Setup product sync webhook
- [ ] Implement cart functionality
- [ ] Handle checkout flow
- [ ] Test order creation and fulfillment

#### Business Initiated Auth (BIA)
- [ ] **Register BIA credentials** with Apple Business Chat
- [ ] Get encryption keys from Apple
- [ ] Implement BIA request format:
  ```json
  {
    "requestIdentifier": "form_bia_ah",
    "responseEncryptionKey": "BASE64_PUBLIC_KEY",
    "oauth": {
      "clientId": "YOUR_CLIENT_ID",
      "scopes": ["profile", "email"]
    }
  }
  ```
- [ ] Implement OAuth flow for BIA
- [ ] Handle encrypted auth responses
- [ ] Decrypt and validate tokens
- [ ] Test BIA on production Business Chat account

#### CSAT Survey (FUNCTIONAL - needs storage)
- [ ] **Setup survey database table**:
  ```sql
  CREATE TABLE csat_responses (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER,
    user_id VARCHAR(255),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP DEFAULT NOW()
  );
  ```
- [ ] Update `csat-survey-qr` response handler to store rating
- [ ] Create analytics dashboard:
  - Average rating
  - Rating distribution
  - Trends over time
- [ ] Implement follow-up actions based on rating:
  - Rating 1-2: Escalate to human agent
  - Rating 3: Send improvement survey
  - Rating 4-5: Thank you message
- [ ] Test CSAT flow end-to-end

#### iMessage Extensions
- [ ] **Develop iMessage app** in Xcode
  - Create new iMessage extension target
  - Design interactive UI
  - Handle app data exchange
- [ ] Configure MSP for iMessage app bubbles
- [ ] Test iMessage app on iOS devices
- [ ] Submit to App Store (if public)

**Estimated Effort**: 7-10 days (multiple external services)

---

## Testing & Quality Assurance

### Unit Tests
- [ ] State catcher retry logic
- [ ] Geocoding API calls
- [ ] Store distance calculations
- [ ] OAuth token handling
- [ ] Rich link metadata parsing

### Integration Tests
- [ ] Complete guitar → AR → payment flow with catchers
- [ ] Store locator → time picker flow
- [ ] Authentication → data storage flow
- [ ] Rich link rendering in Messages app
- [ ] CSAT survey → database storage

### End-to-End Tests
- [ ] Full demo flow on iOS device
- [ ] All interactive elements functional
- [ ] State persistence across sessions
- [ ] Error handling for edge cases
- [ ] Performance under load

### User Acceptance Testing
- [ ] Test with 5-10 beta users
- [ ] Collect feedback on retry thresholds
- [ ] Measure completion rates
- [ ] Identify UX improvements

---

## Documentation

### Technical Documentation
- [x] Implementation specification (TIER-4-IMPLEMENTATION-SPEC.md)
- [x] Implementation guide (TIER-4-IMPLEMENTATION-COMPLETE.md)
- [x] TODO list (this file)
- [ ] API documentation for external services
- [ ] Database schema documentation
- [ ] Deployment guide

### User Documentation
- [ ] Feature overview for end users
- [ ] Bot command reference
- [ ] Troubleshooting guide
- [ ] FAQ

### Developer Documentation
- [ ] Setup guide (local development)
- [ ] n8n workflow import guide
- [ ] Credential configuration guide
- [ ] Testing guide
- [ ] Contributing guide

---

## Performance Optimization

### Current Bottlenecks
- [ ] Identify slow HTTP Request nodes
- [ ] Profile Code node execution times
- [ ] Measure end-to-end latency

### Optimization Opportunities
- [ ] Cache geocoding results (Redis, 24hr TTL)
- [ ] Cache store search results (Redis, 1hr TTL)
- [ ] Parallel HTTP requests where possible
- [ ] Database query optimization (indexes)
- [ ] CDN for static assets (images, files)

### Monitoring
- [ ] Setup application monitoring (Datadog, New Relic)
- [ ] Track workflow execution metrics
- [ ] Alert on error rates > 5%
- [ ] Alert on latency > 5 seconds

---

## Security

### Data Privacy
- [ ] Review PII handling (user names, locations)
- [ ] Implement data retention policies
- [ ] Add GDPR compliance (right to deletion)
- [ ] Encrypt sensitive data at rest

### API Security
- [ ] Rate limiting on all external APIs
- [ ] API key rotation policy
- [ ] OAuth token encryption
- [ ] Input validation and sanitization

### Audit & Compliance
- [ ] Security audit of workflow
- [ ] Penetration testing
- [ ] Compliance review (SOC 2, ISO 27001)
- [ ] Document security policies

---

## Deployment

### Staging Environment
- [ ] Setup staging Chatwoot instance
- [ ] Import workflow to staging
- [ ] Configure staging credentials
- [ ] Test all features in staging
- [ ] Load testing

### Production Deployment
- [ ] Backup existing workflow
- [ ] Import Tier 4 workflow to production
- [ ] Configure production credentials
- [ ] Enable workflow
- [ ] Monitor for errors
- [ ] Rollback plan ready

### Post-Deployment
- [ ] Monitor error rates
- [ ] Collect user feedback
- [ ] Measure feature adoption
- [ ] Iterate based on analytics

---

## Timeline Estimates

| Phase | Features | Effort | Dependencies |
|-------|----------|--------|--------------|
| **Phase 1** | State Catchers (tuning) | 1-2 days | None |
| **Phase 2** | Store Locator | 3-5 days | Geocoding API, Database |
| **Phase 3** | Authentication | 5-7 days | OAuth providers, BIA registration |
| **Phase 4** | Rich Links | 4-6 days | Microservice, App Clip |
| **Phase 5** | Special Integrations | 7-10 days | Shopify, BIA, iMessage app |
| **Testing & QA** | All features | 3-5 days | All phases complete |
| **Deployment** | Production rollout | 1-2 days | Testing complete |
| **Total** | All Tier 4 features | **24-37 days** | External services |

---

## Budget Estimates (External Services)

| Service | Cost | Frequency |
|---------|------|-----------|
| **Google Maps Geocoding API** | $5/1000 requests | Per-use |
| **OpenStreetMap (Nominatim)** | Free | (Rate-limited) |
| **Heroku (Microservice hosting)** | $7-25/month | Monthly |
| **Redis Cloud** | $0-30/month | Monthly |
| **Apple Developer Account** | $99/year | Annual |
| **Shopify Partner Account** | Free | - |
| **Database Hosting (AWS RDS)** | $15-50/month | Monthly |
| **CDN (Cloudflare)** | Free-$20/month | Monthly |
| **Monitoring (Datadog)** | $15-31/host/month | Monthly |
| **Total (Estimated)** | **$42-156/month** + **$99/year** | - |

**Note**: Many services have free tiers suitable for demo/testing.

---

## Success Criteria

### Demo/POC Success
- [x] State catchers functional
- [x] Store locator hardcoded version working
- [x] All placeholders documented
- [x] 130-node workflow runs without errors

### Production Success
- [ ] All external services integrated
- [ ] 95% uptime
- [ ] < 5 second end-to-end latency
- [ ] 90% user satisfaction (CSAT)
- [ ] < 1% error rate

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Geocoding API rate limits** | Medium | High | Implement caching, choose provider with generous limits |
| **OAuth provider downtime** | Low | Medium | Add fallback auth methods, graceful degradation |
| **Apple BIA approval delay** | Medium | High | Apply early, have fallback auth ready |
| **App Clip development complexity** | High | Medium | Start with simple experience, iterate |
| **Database performance issues** | Medium | High | Add indexes, use PostGIS, implement caching |
| **Budget overruns** | Medium | Medium | Use free tiers for testing, optimize API usage |

---

## Next Actions (Immediate)

1. **Import Workflow** to n8n: `Acoustic-House-Bot-TIER4.json`
2. **Assign Credentials** to HTTP Request nodes
3. **Test State Catchers**: Guitar Picker, Apple Pay, Time Picker
4. **Test Store Locator**: Zipcode "94102"
5. **Test Placeholders**: `authenticate`, `rich link`, `shopify`, `survey`
6. **Review TODO Messages** in placeholder nodes
7. **Choose External Services** for Priority 2-5 features
8. **Create Project Plan** with timeline and budget
9. **Begin Phase 1** (State Catcher tuning)

---

## Questions & Support

For questions about specific features, refer to:
- **State Catchers**: See implementation in nodes `ahc1-*`, `ahf1-*`, `ahh1-*`
- **Store Locator**: See implementation in nodes `store-locator-*`
- **Authentication**: See TODO messages in nodes `auth-*`
- **Rich Links**: See TODO messages in nodes `rich-link-*`
- **Special Integrations**: See TODO messages in nodes `shopify-*`, `bia-*`, `csat-*`, `imessage-*`

---

**Last Updated**: 2025-01-10
**Status**: Implementation Complete (Demo), Production TODO
