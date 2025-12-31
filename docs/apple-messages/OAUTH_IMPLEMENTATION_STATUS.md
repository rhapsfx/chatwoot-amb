# OAuth Authentication Implementation Status

## Current State Analysis (January 2025)

### ✅ **COMPLETED COMPONENTS**

#### Backend Infrastructure
1. **AuthenticationService** (`app/services/apple_messages_for_business/authentication_service.rb`)
   - ✅ Creates OAuth2 authentication requests with PKCE
   - ✅ Generates code challenges (S256 method)
   - ✅ Stores auth sessions in Channel JSONB field
   - ✅ Processes OAuth callbacks
   - ✅ Exchanges authorization codes for tokens
   - ✅ Fetches user data from providers

2. **Oauth2Service** (`app/services/apple_messages_for_business/oauth2_service.rb`)
   - ✅ Token exchange for Google, LinkedIn, Facebook
   - ✅ User data fetching with provider-specific endpoints
   - ✅ Token refresh support (Google, LinkedIn)
   - ✅ User data normalization

3. **OauthCallbackController** (`app/controllers/apple_messages_for_business/oauth_callback_controller.rb`)
   - ✅ Processes OAuth2 callbacks from providers
   - ✅ Generates success/error landing pages
   - ✅ Stores authentication results in Redis
   - ✅ Triggers AuthenticationCompleteJob

4. **Channel Model**
   - ✅ `oauth2_providers` JSONB field for storing provider configs
   - ✅ `auth_sessions` JSONB field for storing OAuth state
   - ✅ `oauth2_provider_enabled?(provider)` method
   - ✅ `configured_oauth2_providers` method

#### Frontend Components
1. **AppleAuthModal.vue** (`app/javascript/dashboard/components-next/message/modals/AppleAuthModal.vue`)
   - ✅ Provider selection (Google, LinkedIn, Facebook)
   - ✅ Authentication message customization
   - ✅ Success/Cancel URL configuration
   - ✅ Encryption requirement toggle
   - ✅ Live preview
   - ✅ "Save as Template" functionality

2. **AppleAuthentication.vue** (`app/javascript/dashboard/components-next/message/bubbles/AppleAuthentication.vue`)
   - ✅ Authentication bubble UI
   - ✅ Opens OAuth popup window
   - ✅ Monitors authentication flow
   - ✅ Success/error handling
   - ✅ Provider-specific branding

### ❌ **MISSING COMPONENTS**

#### Critical Missing Pieces

1. **SendAuthenticationService** (NEW - Priority 1)
   - Location: `app/services/apple_messages_for_business/send_authentication_service.rb`
   - Purpose: Send OAuth authentication payloads to Apple MSP
   - Must implement:
     - Build authentication interactive message payload
     - Include `oauth2` object with provider, scopes, code challenge
     - Include `receivedMessage` and `replyMessage`
     - Send to Apple MSP via REST API

2. **PayloadValidatorService OAuth Validation** (UPDATE - Priority 1)
   - Add `validate_oauth_data` method
   - Validate OAuth2 required fields:
     - `scope` (array)
     - `state` (string)
     - `response_type` (must be 'code')
     - `code_challenge_method` (must be 'S256')
     - `code_challenge` (base64 string)
   - Validate `response_encryption_key` (RSA public key)

3. **Bot Service OAuth Handler** (UPDATE - Priority 2)
   - Update `handle_imessage_app` to send OAuth authentication
   - Add `handle_oauth_demo` method
   - Support provider-specific demos (LinkedIn, Facebook, Google)

4. **Message Templates** (NEW - Priority 2)
   - Create default templates for:
     - LinkedIn authentication
     - Facebook authentication
     - Google authentication
   - Templates should include:
     - Provider-specific branding
     - Clear authentication prompts
     - Success/Cancel URLs

5. **ReplyBox Integration** (UPDATE - Priority 3)
   - Add "OAuth Authentication" button to AppleMessagesComposer
   - Open AppleAuthModal when clicked
   - Handle `@create` event from modal
   - Create message via MessageBuilder

6. **IncomingMessageService OAuth Response Handler** (UPDATE - Priority 3)
   - Handle OAuth authentication responses
   - Extract `authorization_code` from interactive response
   - Trigger AuthenticationService.process_oauth2_callback
   - Create conversation message with auth result

### 🔧 **INBOX CONFIGURATION**

#### Required Inbox Settings (Inbox 6)

The `oauth2_providers` JSONB field should contain:

```json
{
  "linkedin": {
    "enabled": true,
    "clientId": "YOUR_LINKEDIN_CLIENT_ID",
    "clientSecret": "YOUR_LINKEDIN_CLIENT_SECRET",
    "scopes": ["r_liteprofile", "r_emailaddress"]
  },
  "google": {
    "enabled": true,
    "clientId": "YOUR_GOOGLE_CLIENT_ID",
    "clientSecret": "YOUR_GOOGLE_CLIENT_SECRET",
    "scopes": ["openid", "profile", "email"]
  },
  "facebook": {
    "enabled": true,
    "clientId": "YOUR_FACEBOOK_APP_ID",
    "clientSecret": "YOUR_FACEBOOK_APP_SECRET",
    "scopes": ["public_profile", "email"]
  }
}
```

**⚠️ IMPORTANT:** Inbox settings validation is currently disabled (line 52 in channel model). Re-enable after OAuth is fully tested.

### 📋 **IMPLEMENTATION CHECKLIST**

#### Phase 1: Core Send Service (1-2 hours)
- [ ] Create `SendAuthenticationService`
- [ ] Implement payload building
- [ ] Test with Apple MSP sandbox
- [ ] Add CaseTransformer integration
- [ ] Add logging/error handling

#### Phase 2: Validation & Bot (1 hour)
- [ ] Update PayloadValidatorService with OAuth validation
- [ ] Implement bot OAuth demo handlers
- [ ] Create default message templates
- [ ] Test bot OAuth flow

#### Phase 3: UI Integration (1 hour)
- [ ] Add OAuth button to ReplyBox
- [ ] Connect AppleAuthModal to MessageBuilder
- [ ] Test end-to-end flow
- [ ] Add i18n strings

#### Phase 4: Response Handling (30 minutes)
- [ ] Update IncomingMessageService for OAuth responses
- [ ] Handle authentication success/failure
- [ ] Create conversation messages
- [ ] Test callback flow

### 🧪 **TESTING REQUIREMENTS**

1. **Unit Tests**
   - SendAuthenticationService payload building
   - PayloadValidatorService OAuth validation
   - AuthenticationService flow

2. **Integration Tests**
   - Complete OAuth flow (provider → Apple MSP → callback)
   - Bot OAuth demo
   - ReplyBox OAuth creation

3. **Manual Testing**
   - Test with LinkedIn account
   - Test with Google account
   - Test with Facebook account
   - Verify encryption key generation
   - Verify PKCE code challenge

### 📚 **APPLE MSP OAUTH PAYLOAD STRUCTURE**

```json
{
  "v": 1,
  "id": "unique-message-id",
  "sourceId": "urn:biz:YOUR_MSP_ID",
  "destinationId": "urn:biz:CUSTOMER_SOURCE_ID",
  "type": "interactive",
  "interactiveData": {
    "bid": "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.authentication",
    "data": {
      "oauth2": {
        "scope": ["openid", "profile", "email"],
        "state": "secure-random-state",
        "response_type": "code",
        "code_challenge_method": "S256",
        "code_challenge": "base64-encoded-challenge"
      }
    },
    "response_encryption_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----",
    "receivedMessage": {
      "title": "Sign in with Google",
      "subtitle": "Authenticate to continue",
      "imageIdentifier": "google_icon",
      "style": "large"
    },
    "replyMessage": {
      "title": "Authentication Complete",
      "imageIdentifier": "success_icon"
    }
  }
}
```

### 🔐 **SECURITY CONSIDERATIONS**

1. **PKCE Implementation**
   - ✅ Code verifier generation (secure random)
   - ✅ S256 challenge method
   - ⚠️ Verifier storage needs review

2. **State Parameter**
   - ✅ Secure random generation
   - ✅ Stored in Channel auth_sessions
   - ✅ Expires after 1 hour

3. **Response Encryption**
   - ✅ RSA key pair generation via KeyPairService
   - ⚠️ Public key included in payload
   - ⚠️ Private key used to decrypt Apple response

4. **Token Storage**
   - ⚠️ Access tokens stored in Redis (temporary)
   - ⚠️ Consider encrypted storage for long-term tokens

### 📖 **REFERENCES**

- Apple Business Chat OAuth: https://developer.apple.com/documentation/businesschatapi/messages_sent/interactive_messages/oauth_2_authentication
- OAuth 2.0 PKCE: https://tools.ietf.org/html/rfc7636
- LinkedIn OAuth: https://docs.microsoft.com/en-us/linkedin/shared/authentication/authentication
- Google OAuth: https://developers.google.com/identity/protocols/oauth2
- Facebook OAuth: https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow

---

## NEXT STEPS

1. **Immediate** (Priority 1): Create SendAuthenticationService
2. **Immediate** (Priority 1): Add PayloadValidatorService OAuth validation
3. **Short-term** (Priority 2): Implement bot OAuth handlers
4. **Short-term** (Priority 2): Create default templates
5. **Medium-term** (Priority 3): Complete UI integration
