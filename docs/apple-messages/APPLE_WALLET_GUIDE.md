# Apple Wallet Pass for Acoustic House Bot - Complete Guide

**Version**: 1.0
**Last Updated**: March 2026
**Status**: ✅ Implemented — requires Apple Developer certificate setup before use

---

## Table of Contents

1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [Prerequisites — Apple Developer Setup](#prerequisites--apple-developer-setup)
   - [Step 1: Create a Pass Type ID](#step-1-create-a-pass-type-id)
   - [Step 2: Download the Signing Certificate](#step-2-download-the-signing-certificate)
   - [Step 3: Export PEM Files](#step-3-export-pem-files)
   - [Step 4: Download the WWDR Certificate](#step-4-download-the-wwdr-certificate)
4. [Required Image Assets](#required-image-assets)
   - [Image Specifications](#image-specifications)
   - [Design Guidelines](#design-guidelines)
5. [Environment Variables](#environment-variables)
6. [Pass Content & Structure](#pass-content--structure)
   - [Pass Layout](#pass-layout)
   - [QR Code](#qr-code)
   - [Geo-Trigger Location](#geo-trigger-location)
7. [Bot Flow Integration](#bot-flow-integration)
   - [Trigger 1: After Time Picker (Main Flow)](#trigger-1-after-time-picker-main-flow)
   - [Trigger 2: "wallet" Keyword](#trigger-2-wallet-keyword)
   - [Trigger 3: Summary List Picker](#trigger-3-summary-list-picker)
   - [Name Collection (AHW1 State)](#name-collection-ahw1-state)
8. [Code Architecture](#code-architecture)
9. [Testing the Integration](#testing-the-integration)
10. [Troubleshooting](#troubleshooting)
11. [Deployment Checklist](#deployment-checklist)

---

## Overview

The Acoustic House bot generates a personalized **Apple Wallet pickup pass** (`.pkpass`) after a customer schedules their guitar lesson. The pass is delivered inline in the Apple Messages for Business conversation — iOS recognizes the `.pkpass` MIME type and presents the native "Add to Wallet" prompt automatically.

The pass includes:
- Customer name and guitar model
- Selected Apple Store and pickup timeslot
- QR code for in-store check-in
- Geo-trigger: lock screen notification when the customer arrives near the store

---

## How It Works

```
Customer selects a time in the Time Picker
            ↓
handle_time_picker_response stores selected_timeslot
            ↓
send_wallet_pass called
            ↓
WalletPassService.generate
  ├── Reads custom_attributes (name, guitar, store, timeslot, coordinates)
  ├── Builds pass.json with QR code + location trigger
  ├── Signs via passbook2 gem (PKCS #7 + WWDR cert)
  └── Returns .pkpass binary (signed ZIP archive)
            ↓
ActiveStorage::Blob.create_and_upload! (MIME: application/vnd.apple.pkpass)
            ↓
Messages::MessageBuilder sends blob as attachment
            ↓
iOS shows "Add to Wallet" prompt in Messages conversation
```

---

## Prerequisites — Apple Developer Setup

> **Cost**: Free — a basic Apple Developer account is sufficient.

### Step 1: Create a Pass Type ID

1. Sign in to [developer.apple.com](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles → Identifiers**
3. Click **+** and select **Pass Type IDs**
4. Enter a description (e.g. `Acoustic House Wallet Pass`) and an identifier in reverse-DNS format:
   ```
   pass.net.rhaps.acoustichouse
   ```
5. Click **Register**

> **Note**: The Pass Type ID becomes your `WALLET_PASS_TYPE_ID` ENV var. It must match exactly what you put in `pass.json`.

---

### Step 2: Download the Signing Certificate

1. In the Identifiers list, click on your new Pass Type ID
2. Click **Create Certificate** under **Production Certificates**
3. Follow the prompts to generate a Certificate Signing Request (CSR) from your Mac:
   - Open **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**
   - Enter your email, choose **Save to disk**, click **Continue**
4. Upload the `.certSigningRequest` file
5. Download the resulting `.cer` file (e.g. `pass.cer`)
6. Double-click the `.cer` file to install it in Keychain Access

---

### Step 3: Export PEM Files

Once the certificate is in your Keychain:

```bash
# Export the certificate (public key)
openssl x509 -in pass.cer -inform DER -out wallet_cert.pem -outform PEM

# Export the private key — find it in Keychain Access under "My Certificates"
# Right-click the private key → Export → save as .p12 → enter an export password
# Then convert to PEM:
openssl pkcs12 -in private_key.p12 -nocerts -nodes -out wallet_key.pem
# (enter the export password when prompted)
```

The content of `wallet_cert.pem` becomes `WALLET_CERT_PEM`.
The content of `wallet_key.pem` becomes `WALLET_KEY_PEM`.
If you set an export password, put it in `WALLET_KEY_PASSWORD` (defaults to empty string).

---

### Step 4: Download the WWDR Certificate

Apple's Worldwide Developer Relations (WWDR) intermediate certificate must be included in the signature chain.

1. Download from Apple: [https://www.apple.com/certificateauthority/](https://www.apple.com/certificateauthority/)
   - Download **Apple Worldwide Developer Relations Certification Authority - G4** (or latest)
2. Convert if needed:
   ```bash
   openssl x509 -in AppleWWDRCAG4.cer -inform DER -out wwdr.pem -outform PEM
   ```

The content of `wwdr.pem` becomes `WALLET_WWDR_PEM`.

---

### Finding Your Team ID

Your Team ID is the 10-character string visible in the top-right of the Apple Developer portal (e.g. `ABC1234567`). It also appears in your certificate's Subject: `OU=XXXXXXXXXX`.

---

## Required Image Assets

Place PNG image files in `app/assets/images/wallet/`. The service gracefully skips any file that does not exist — the pass will still generate but without that image.

### Image Specifications

| File | Dimensions | Purpose |
|------|-----------|---------|
| `icon.png` | 114 × 114 px | Lock screen, notification center |
| `icon@2x.png` | 228 × 228 px | Retina displays |
| `logo.png` | 320 × 100 px | Pass header (top-left) |
| `logo@2x.png` | 640 × 200 px | Retina displays |

> **Tip**: At minimum, provide `icon@2x.png` and `logo@2x.png` — modern iPhones always use @2x or @3x assets. The @1x files can be the same images at half the resolution.

### Design Guidelines

- **Format**: PNG only (no JPEG, no SVG)
- **Color space**: sRGB
- **Background**: The icon should have a solid background (iOS masks it to a rounded rect); the logo can have a transparent background — it will appear over `backgroundColor`
- **No text** in the logo image — use the `logoText` field in pass.json instead
- **Margins**: Leave ~15% padding inside the icon border to prevent clipping

**Current pass colors** (defined in `WalletPassService#base_pass_structure`):
```
backgroundColor: rgb(20, 20, 30)     — near-black dark background
foregroundColor: rgb(255, 255, 255)  — white text
labelColor:      rgb(160, 160, 180)  — muted blue-grey labels
```
Design the logo and icon to look good on a dark background.

---

## Environment Variables

Add the following to your `.env` file (development) and to the production Docker environment config.

```bash
# Pass Type Identifier (from Apple Developer portal, Identifiers → Pass Type IDs)
WALLET_PASS_TYPE_ID=pass.net.rhaps.acoustichouse

# Apple Developer Team ID (10 chars, visible in developer.apple.com top-right)
WALLET_TEAM_ID=XXXXXXXXXX

# PEM-encoded signing certificate (the content of wallet_cert.pem — include header/footer lines)
WALLET_CERT_PEM="-----BEGIN CERTIFICATE-----
MIIFnjCCBCSgAwIBAgIIb...
-----END CERTIFICATE-----"

# PEM-encoded private key (the content of wallet_key.pem)
WALLET_KEY_PEM="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9...
-----END PRIVATE KEY-----"

# Optional: export password for the private key (leave empty if none was set)
WALLET_KEY_PASSWORD=

# PEM-encoded Apple WWDR intermediate certificate (wwdr.pem)
WALLET_WWDR_PEM="-----BEGIN CERTIFICATE-----
MIIEVTCCAj2gAwIBAgIIP...
-----END CERTIFICATE-----"
```

> **Security**: Never commit PEM content to git. Use Rails credentials (`rails credentials:edit`) or environment-specific secrets management for production.

**Multi-line PEM in Docker / docker-compose**:
```yaml
environment:
  WALLET_PASS_TYPE_ID: "pass.net.rhaps.acoustichouse"
  WALLET_TEAM_ID: "XXXXXXXXXX"
  WALLET_CERT_PEM: |
    -----BEGIN CERTIFICATE-----
    MIIFnjCCBCSgAwIBAgIIb...
    -----END CERTIFICATE-----
  WALLET_KEY_PEM: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9...
    -----END PRIVATE KEY-----
  WALLET_WWDR_PEM: |
    -----BEGIN CERTIFICATE-----
    MIIEVTCCAj2gAwIBAgIIP...
    -----END CERTIFICATE-----
```

---

## Pass Content & Structure

### Pass Layout

The pass uses the `generic` pass type with three field groups:

```
┌─────────────────────────────────┐
│  🎵  Acoustic House             │  ← logoText
├─────────────────────────────────┤
│  YOUR LESSON                    │  ← primaryField label
│  John Doe                       │  ← primaryField value (customer_name)
├──────────────────┬──────────────┤
│  GUITAR          │  STORE       │  ← secondaryFields
│  Gibson Les Paul │  Apple Park  │
├─────────────────────────────────┤
│  PICKUP TIME                    │  ← auxiliaryField
│  April 2 @ 3:30 PM              │
├─────────────────────────────────┤
│  [  QR CODE  ]                  │  ← barcode (PKBarcodeFormatQR)
│  AH-123-1712345678              │
└─────────────────────────────────┘
```

**Fallback values** (when conversation data is unavailable):
| Field | Fallback |
|-------|---------|
| Customer name | `Guest` |
| Guitar | `Guitar` |
| Store | `Apple Store` |
| Pickup time | `TBD` |

### QR Code

The barcode encodes two pieces of information:

| Field | Content | Example |
|-------|---------|---------|
| `message` (scannable) | Unique serial number | `AH-42-1712345678` |
| `altText` (human readable) | Full details below QR | `John Doe \| Gibson Les Paul \| April 2 @ 3:30PM \| Apple Park` |

The serial number is generated once per conversation and stored in `conversation.custom_attributes['wallet_serial_number']` for idempotency — regenerating the pass uses the same serial number.

**Serial number format**: `AH-{conversation_id}-{unix_timestamp}`

### Geo-Trigger Location

If `store_search_lat` and `store_search_lon` are stored in the conversation's `custom_attributes` (set automatically when the user picks a store), the pass includes a `locations` entry:

```json
{
  "locations": [{
    "latitude": 37.3349,
    "longitude": -122.0090,
    "relevantText": "Your guitar lesson is nearby! 🎸"
  }]
}
```

iOS displays this text on the lock screen when the customer is within ~100 metres of the store. No additional configuration is needed — the coordinates come from the store selection step in the bot flow.

---

## Bot Flow Integration

The wallet pass is generated in three scenarios:

### Trigger 1: After Time Picker (Main Flow)

When a customer completes the time picker in the main bot flow, the pass is automatically generated and sent before the "Shall we continue?" prompt.

**Code path**:
`handle_time_picker_response` → `send_wallet_pass` → `update_bot_state('AHH2')` → `handle_continue_prompt`

The pass will contain all available data since by this point the bot has collected the customer name, guitar selection, store, and timeslot.

---

### Trigger 2: "wallet" Keyword

Any of the following keywords trigger the wallet demo at any time:

| Keyword | Fuzzy match also works |
|---------|----------------------|
| `wallet` | `walet`, `walllet` |
| `walletpass` | — |
| `wallet pass` | — |
| `apple wallet` | — |

The keyword sets bot state to `DEMO_MODE` after the pass is sent, so the main flow is not disturbed.

---

### Trigger 3: Summary List Picker

Selecting **"Apple Wallet"** (item 2) from the summary list picker calls `handle_wallet_demo`, which generates and sends the pass.

---

### Name Collection (AHW1 State)

When the wallet is triggered via keyword or summary list picker before the main flow has collected the customer name, the bot asks for it first:

```
Bot:      "To generate your Guitar Lesson Pickup Pass, what's your name?"
Customer: "Maria Garcia"
Bot:      [sends .pkpass file]
          "🎫 Your Guitar Lesson Pickup Pass — tap to add to Apple Wallet!"
```

This uses the `AHW1` bot state. After the pass is sent, state transitions to `DEMO_MODE`.

If the customer name is already in `conversation.custom_attributes['customer_name']` (set during the main flow's form/name steps), the pass is sent immediately without asking.

---

## Code Architecture

| File | Role |
|------|------|
| `app/services/apple_messages_for_business/wallet_pass_service.rb` | Generates the `.pkpass` binary — reads conversation data, builds `pass.json`, signs via `passbook2`, returns binary |
| `app/services/apple_messages_for_business/bot_message_sender.rb` | `send_wallet_pass` method — uploads pass to ActiveStorage, creates message with attachment |
| `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` | `handle_wallet_demo`, `handle_wallet_name_input`, keyword registration, summary LP routing, time picker hook |
| `app/services/apple_messages_for_business/bot_state_manager.rb` | `AHW1` added to `VALID_STATES` |
| `app/assets/images/wallet/` | Pass image assets (icon, logo) — **must be added manually** |
| `Gemfile` | `gem 'passbook2'` — handles PKCS #7 signing and ZIP packaging |

**Gem used**: [`passbook2`](https://rubygems.org/gems/passbook2) — a Ruby gem for generating Apple Wallet passes, updated for OpenSSL 3.0 compatibility.

**Key `WalletPassService` methods**:

| Method | Purpose |
|--------|---------|
| `generate` | Public entry point — validates ENV, configures passbook2, builds and signs the pass |
| `build_pass_json` | Assembles the pass JSON from sub-methods |
| `base_pass_structure` | Core pass metadata (org name, colors, identifiers) |
| `generic_fields` | The pass fields (name, guitar, store, time) |
| `barcode_data` | QR code configuration with serial number and alt text |
| `geo_trigger` | Location entry for the lock screen notification |
| `serial_number` | Idempotent serial — reads or creates `wallet_serial_number` in custom_attributes |
| `attach_images` | Adds `icon.png`, `icon@2x.png`, `logo.png`, `logo@2x.png` from `app/assets/images/wallet/` |
| `validate_env!` | Raises a clear error if any required ENV var is missing |

---

## Testing the Integration

### Quick Smoke Test (Rails Console)

```ruby
# Find a conversation that has gone through the bot flow
conv = Conversation.find(ID)

# Check available attributes
puts conv.custom_attributes.slice('customer_name', 'selected_guitar', 'selected_store_name', 'selected_timeslot', 'store_search_lat', 'store_search_lon')

# Generate the pass (requires WALLET_* ENV vars to be set)
service = AppleMessagesForBusiness::WalletPassService.new(conv)
data = service.generate
File.binwrite('/tmp/test.pkpass', data)
puts "Written #{data.bytesize} bytes to /tmp/test.pkpass"
```

Then open `/tmp/test.pkpass` on an iPhone (AirDrop it or upload somewhere) to verify it installs in Wallet.

### End-to-End Test

1. Start the bot on an iPhone with Apple Messages
2. Type `startover` to begin a fresh flow
3. Complete through the Time Picker step — the Wallet pass should arrive automatically after confirming a timeslot
4. Tap **Add to Wallet** on the received attachment
5. Verify all fields show correct data (name, guitar, store, time)
6. Check the QR code scans and shows the serial number + alt text
7. If store coordinates were set: walk/drive near the selected Apple Store and verify the lock screen notification appears

### Keyword Test

Type `wallet` at any point during the conversation. If your name has already been captured, the pass arrives immediately. If not, the bot asks for your name first.

---

## Troubleshooting

### "WalletPassService: missing ENV vars: WALLET_CERT_PEM, ..."

One or more required ENV vars are not set. Check your `.env` file and ensure the PEM content is correctly formatted (with `-----BEGIN CERTIFICATE-----` header lines).

### Pass installs but shows incorrect/blank fields

Check `conversation.custom_attributes` — the fields `customer_name`, `selected_guitar`, `selected_store_name`, `selected_timeslot` must be populated before the pass is generated. In the keyword/summary LP demo path before the main flow completes, only `customer_name` will be set (or collected via AHW1).

### "invalid signature" / pass won't install

- Verify your Pass Type ID in `WALLET_PASS_TYPE_ID` matches exactly what is registered in the Apple Developer portal
- Verify `WALLET_TEAM_ID` matches the Team ID on your signing certificate
- Ensure `WALLET_WWDR_PEM` is the **current** Apple WWDR cert (G4 or later — older G3 cert expired 2023)
- Check that the certificate is not expired (Pass Type ID certs expire after 1 year and must be renewed)

### Pass generates but no geo notification near store

- The `store_search_lat` / `store_search_lon` custom attributes must be set. These are populated only when the user goes through the location → store selection step in the main flow.
- In keyword/demo mode these coordinates are typically not set — the pass is generated without a location trigger (this is expected behaviour).
- iOS location services must be enabled for Wallet in Settings → Privacy → Location Services → Wallet.

### Sidekiq / bot not picking up new keywords

After restarting the server (`./script/dev-server.sh restart`), the new `DEMO_KEYWORDS` constants and `AHW1` state are loaded. If keywords are still not recognised, verify the restart completed (`status` command).

---

## Deployment Checklist

Before going live:

- [ ] Pass Type ID created in Apple Developer portal
- [ ] Signing certificate downloaded, not expired
- [ ] PEM files exported: `wallet_cert.pem`, `wallet_key.pem`, `wwdr.pem`
- [ ] All 5 `WALLET_*` ENV vars set in production Docker config
- [ ] 4 image assets placed in `app/assets/images/wallet/`:
  - [ ] `icon.png` (114×114)
  - [ ] `icon@2x.png` (228×228)
  - [ ] `logo.png` (320×100)
  - [ ] `logo@2x.png` (640×200)
- [ ] Full Docker rebuild deployed (`./script/deploy-production-docker.sh`) to include the new gem and assets
- [ ] End-to-end test on a real iPhone: complete bot flow → receive pass → Add to Wallet

---

*Related guides*:
- [APPLE_PAY_GUIDE.md](APPLE_PAY_GUIDE.md) — Apple Pay integration (similar certificate workflow)
- [ACOUSTIC_HOUSE_BOT_CONFIGURATION_GUIDE.md](ACOUSTIC_HOUSE_BOT_CONFIGURATION_GUIDE.md) — Full bot setup
- [BOT_KEYWORDS.md](BOT_KEYWORDS.md) — All registered bot keywords
