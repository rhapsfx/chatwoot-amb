# Acoustic House Bot - Complete Analysis: Python vs n8n

## Executive Summary

**Current Implementation Status**: ❌ **INCOMPLETE** - Only ~20% of Python logic implemented

The current n8n workflow implements a **simplified menu-driven flow** but is missing the **core sequential demo flow** (AHA1 → AHK3) that represents the primary Acoustic House experience.

---

## Python File Structure Analysis

### Entry Points (Line References)

**1. `interactivePayload(payload)`** (Lines 42-132)
- Handles ALL interactive message responses
- Routes to 26 different handler functions
- Processes List Pickers, Quick Replies, Forms, Time Pickers, Apple Pay

**2. `receivedMessage(payload)`** (Lines 134-247)
- Handles text message input
- Routes to 40+ different menu functions
- Manages flow state machine (AHA1 → AHK3)

---

## Complete Function Mapping

### Interactive Response Handlers (from functionList line 85-111)

| Request ID | Handler Function | Line | Status in n8n | Purpose |
|------------|------------------|------|---------------|---------|
| `qr_travel` | AHA2 | 947 | ❌ MISSING | Region selection (Americas/EMEA/APAC) |
| `form_help_me_decide` | AHB1 | 973 | ❌ MISSING | "Help Me Decide" form response |
| `qr_name` | AHB2 | 991 | ❌ MISSING | Name selection (formal/stage name) |
| `qr_view_ar` | AHE1 | 1073 | ⚠️ PARTIAL | First AR question - "Did you see AR?" |
| `qr_place_ar` | AHE1 | 1073 | ⚠️ PARTIAL | Second AR question - "Did you place it?" |
| `qr_continue` | AHI1 | 1201 | ❌ MISSING | Continue after time picker |
| `qr_learn_more` | AHK1 | 1280 | ❌ MISSING | Learn more about Messages |
| `qr_photo` | AHJ1 | 1240 | ❌ MISSING | Photo sharing question |
| `form_covid_quest` | AHH2 | 1191 | ❌ MISSING | COVID questionnaire form |
| `lp_guitar_0319` | requestIdGuitar | 756 | ✅ DONE | Guitar selection handler |
| `lp_startover_1018` | requestIdStartOver | 794 | ❌ MISSING | Start over menu |
| `auth1220181p1` | requestIdAuth | 808 | ❌ MISSING | LinkedIn authentication |
| `applepay_1018` | requestIdApplePay | 847 | ⚠️ PARTIAL | Apple Pay response |
| `time_1218` | requestIdTimePicker | 876 | ⚠️ PARTIAL | Time picker response |
| `time_0319` | requestIdTimePicker | 876 | ⚠️ PARTIAL | Time picker response |
| `lp_summary_0319` | requestIdSendFile | 871 | ❌ MISSING | Send file from summary |
| `lp_menu_0319` | requestMenu | 300 | ⚠️ PARTIAL | Main menu selection |
| `geoCode0504` | requestGeoCode | 737 | ❌ MISSING | Geocode selection → stores |
| `store0419` | requestStore | 748 | ❌ MISSING | Store selection → time picker |
| `region_0506` | requestRegion | 729 | ❌ MISSING | Region selection handler |
| `shopify_menu` | requestShopify | 289 | ❌ MISSING | Shopify integration |
| `linkedin_server_side` | serverSideResponse | 829 | ❌ MISSING | Server-side auth response |
| `linkedin_response` | sendAuthStatus | 841 | ❌ MISSING | Auth status display |
| `form_bia_ah` | send_bia | 497 | ❌ MISSING | Business Initiated Auth |
| `guitar_order` | send_fake_bia | 483 | ❌ MISSING | Guitar order updates |

**Summary**: 3/25 fully implemented (12%), 5/25 partially (20%)

---

## The Core Demo Flow (AHA1 → AHK3)

### ❌ COMPLETELY MISSING from n8n

This is the **main sequential experience** that guides users through the entire Acoustic House demo:

#### **Phase 1: Welcome & Region (AHA1 → AHA3)**

**AHA1** (Lines 929-939)
```python
def AHA1(usr):
    # Welcome message
    sendMessage(AH_ID, usr.userId, "Thanks for checking out Business Chat...")
    # Ask region question
    sendMessage(AH_ID, usr.userId, "Before we begin, where are you in the world?")
    sendInteractive(AH_ID, usr.userId, "qr_travel.json", usr.lang)
    dbLastMessage(usr.userId, "AHA2")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Welcome user, ask for region (Americas/EMEA/APAC)
- **Next**: Routes to AHA2

**AHA2** (Lines 947-958)
```python
def AHA2(usr):
    if usr.selection == 2:
        region = "APAC"
    elif usr.selection == 1:
        region = "EMEA"
    else:
        region = "Americas"
    updateRegion(usr.userId, region)
    AHA3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Process region selection, store in DB
- **Next**: Routes to AHA3

**AHA3** (Lines 960-970)
```python
def AHA3(usr):
    sendMessage(AH_ID, usr.userId, "Thank you, let's help you find your next guitar:")
    if "FORM" in str(usr.payload["capability-list"]):
        sendInteractive(AH_ID, usr.userId, "help_me_decide.json", usr.lang)
        dbLastMessage(usr.userId, "AHB1")
    else:
        sendMessage(AH_ID, usr.userId, "...What is your name?")
        dbLastMessage(usr.userId, "AHB1_2")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send "Help Me Decide" form OR ask for name directly
- **Next**: Routes to AHB1 (form) or AHB1_2 (text input)

---

#### **Phase 2: Name Collection & Guitar Selection (AHB1 → AHC1)**

**AHB1** (Lines 973-989) - Form Response
```python
def AHB1(usr):
    selection_json = usr.selection
    updateName(usr.userId, selection_json[4]["items"][0]["value"])
    stage_name = selection_json[5]["items"][0]["value"]
    if stage_name != "":
        sendInteractive(AH_ID, usr.userId, "qr_name.json", usr.lang)
    else:
        AHB3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Process "Help Me Decide" form, extract name and optional stage name
- **Next**: Routes to AHB2 (if stage name) or AHB3

**AHB2** (Lines 991-999) - Name Selection
```python
def AHB2(usr):
    if usr.selection == 0:
        selectedName = findUserName(usr.userId)  # Use real name
    else:
        selectedName = getIntent(usr.userId)     # Use stage name
    updateName(usr.userId, selectedName)
    AHB3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Let user choose between real name and stage name
- **Next**: Routes to AHB3

**AHB1_2** (Lines 1001-1005) - Text Name Input
```python
def AHB1_2(usr):
    name = usr.message.capitalize()
    updateName(usr.userId, name)
    AHB3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle text input for name (when form not supported)
- **Next**: Routes to AHB3

**AHB3** (Lines 1007-1011) - Send Guitar List
```python
def AHB3(usr):
    sendMessage(AH_ID, usr.userId, f"Hello {findUserName(usr.userId)}. We have some cool guitars...")
    sendInteractive(AH_ID, usr.userId, "guitar_listpicker.json", usr.lang)
    dbLastMessage(usr.userId, "AHC1")
```
- **n8n Status**: ⚠️ Partially implemented (guitar list exists, but not this flow)
- **Purpose**: Greet by name, send guitar list picker
- **Next**: Routes to AHC1 (catcher state)

**AHC1** (Lines 1013-1035) - Guitar Selection Catcher
```python
def AHC1(usr):
    # Increment + counter, handle stuck users
    count = usr.lastMessage.count("+")
    if count == 2:
        sendMessage(AH_ID, usr.userId, "Looks like we're waiting for you to select a guitar...")
    elif count == 3:
        sendInteractive(AH_ID, usr.userId, "guitar_listpicker.json", usr.lang)  # Resend
    elif count > 5:
        sendMessage(AH_ID, usr.userId, "Okay, we will just pretend you selected the Martin DC28E...")
        usr.selection = "Martin DC28E Dreadnought"
        requestIdGuitar(usr)  # Force continuation
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle users stuck on guitar selection with incremental prompts
- **Next**: Waits for guitar selection → requestIdGuitar → AHC2

---

#### **Phase 3: AR Experience (AHC2 → AHE2)**

**AHC2** (Lines 1037-1046) - Send AR File
```python
def AHC2(usr):
    sendMessage(AH_ID, usr.userId, "Just in. We have this cool Stratocaster. Check it out!!!")
    sendFile(AH_ID, usr.userId, "stratocaster.usdz")  # Send AR file
    userStat = awkStop(usr.userId, "AHC3", 20)  # Wait 20 seconds
    if userStat != "stop":
        AHC3(usr)
```
- **n8n Status**: ⚠️ Partially implemented (AR file sending exists, but not this flow)
- **Purpose**: Send AR file after guitar selection
- **Next**: Routes to AHC3

**AHC3** (Lines 1048-1054) - First AR Question
```python
def AHC3(usr):
    sendMessage(AH_ID, usr.userId, "Did you click on the image and see the 3D AR view?")
    sendInteractive(AH_ID, usr.userId, "qr_view_ar.json", usr.lang)
    dbLastMessage(usr.userId, "AHD1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Ask if user viewed AR (Yes/No quick reply)
- **Next**: Routes to AHD1

**AHD1** (Lines 1056-1071) - First AR Response Handler
```python
def AHD1(usr):
    if usr.selection == 0:  # Yes
        sendMessage(AH_ID, usr.userId, f"Awesome! {userName} did you select AR and set it down?")
        sendInteractive(AH_ID, usr.userId, "qr_place_ar.json", usr.lang)
    else:  # No
        sendMessage(AH_ID, usr.userId, "Try tapping on the image to see the AR image!")
        sendMessage(AH_ID, usr.userId, "Did you select AR and set it down in front of you?")
        sendInteractive(AH_ID, usr.userId, "qr_place_ar.json", usr.lang)
    dbLastMessage(usr.userId, "AHE1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle first AR question response, ask second question
- **Next**: Routes to AHE1

**AHE1** (Lines 1073-1087) - Second AR Response Handler
```python
def AHE1(usr):
    if usr.selection == 1:  # No
        sendMessage(AH_ID, usr.userId, "Try tapping on the image to see the AR image!")
    sendMessage(AH_ID, usr.userId, f"Great, let's buy your new {getGuitar(usr.userId)}.")
    if userStatus(usr.userId) != "stop":
        AHE2(usr)  # Send Apple Pay
```
- **n8n Status**: ⚠️ Partially implemented (n8n has one AR prompt, not two)
- **Purpose**: Handle second AR question, transition to Apple Pay
- **Next**: Routes to AHE2

**AHE2** (Lines 1089-1095) - Send Apple Pay
```python
def AHE2(usr):
    if sendApplePay(usr.userId, getGuitar(usr.userId), usr.lang, biz_id=AH_ID) != "Message Success":
        sendMessage(AH_ID, usr.userId, "Technical difficulties...")
    dbLastMessage(usr.userId, "AHF1")
```
- **n8n Status**: ⚠️ Partially implemented (Apple Pay exists, but not in this flow)
- **Purpose**: Send Apple Pay request
- **Next**: Routes to AHF1 (catcher state)

---

#### **Phase 4: Apple Pay & Lesson Scheduling (AHF1 → AHH2)**

**AHF1** (Lines 1097-1109) - Apple Pay Catcher
```python
def AHF1(usr):
    # Increment + counter for users who don't pay
    count = usr.lastMessage.count("+")
    if count > 2:
        sendMessage(AH_ID, usr.userId, f"Just kidding {row[1]}. No payment was processed.")
        if userStatus(usr.userId) != "stop":
            AHF2(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle users stuck on Apple Pay
- **Next**: Routes to AHF2

**AHF2** (Lines 1111-1118) - Schedule Lesson Intro
```python
def AHF2(usr):
    sendMessage(AH_ID, usr.userId, f"However, let's schedule a lesson with your {getGuitar(usr.userId)}.")
    if userStatus(usr.userId) != "stop":
        AHF3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Transition message to lesson scheduling
- **Next**: Routes to AHF3

**AHF3** (Lines 1119-1128) - Request Location
```python
def AHF3(usr):
    if getIntent(usr.userId) == "Traveling":
        sendMessage(AH_ID, usr.userId, "We can find locations near your travel destination...")
    else:
        sendMessage(AH_ID, usr.userId, "We can find the closest location for you...")
    dbLastMessage(usr.userId, "AHG1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Ask for zipcode/location
- **Next**: Routes to AHG1

**AHG1** (Lines 1130-1166) - Location Processing & Store List
```python
def AHG1(usr):
    # Try to parse zipcode or Apple Maps link
    if "maps.apple.com" in usr.message:
        # Extract lat/long from link
        usr.pt = [float(latLong[0]), float(latLong[1])]
        findStores(usr)
    else:
        # Geocode the zipcode
        geoCodeResults = findGlobalGeocode(usr.message, getRegion(usr.userId))
        if len(geoCodeResults) == 1:
            # Direct match
        elif len(geoCodeResults) > 1:
            send_geocode_listpicker(usr.userId, geoCodeResults, usr.lang)  # Multiple matches
        # Send time picker or store list
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Process location input, geocode, find stores
- **Next**: Routes to store selection or time picker

**AHH1** (Lines 1168-1190) - Time Picker Catcher
```python
def AHH1(usr):
    # Increment + counter for users who don't pick time
    count = usr.lastMessage.count("+")
    if count == 2:
        sendMessage(AH_ID, usr.userId, "Looks like we're waiting for you to select a time...")
    elif count == 3:
        sendLocalTimePicker(...)  # Resend
    elif count == 5:
        sendMessage(AH_ID, usr.userId, "You must be a shredding pro, we can skip...")
        AHH2(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle users stuck on time picker
- **Next**: Routes to AHH2

**AHH2** (Lines 1191-1199) - Time Picker Confirmation
```python
def AHH2(usr):
    sendMessage(AH_ID, usr.userId, "Thank you for your co-operation, you're all set to shread. 🤘")
    sendMessage(AH_ID, usr.userId, "Shall we continue?")
    sendInteractive(AH_ID, usr.userId, "qr_continue.json", usr.lang)
    dbLastMessage(usr.userId, "AHI1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Confirm lesson booking, ask to continue
- **Next**: Routes to AHI1

---

#### **Phase 5: Rich Links & Photos (AHI1 → AHJ4)**

**AHI1** (Lines 1201-1217) - Continue or Skip
```python
def AHI1(usr):
    if usr.selection == 1:  # Skip
        dbLastMessage(usr.userId, "AHK1")  # Jump to learn more
        sendMessage(AH_ID, usr.userId, f"{userName}, would you like to learn more?")
        sendInteractive(AH_ID, usr.userId, "qr_learn_more.json", usr.lang)
    else:  # Continue
        sendMessage(AH_ID, usr.userId, "There's so much more you can do like sharing beautiful links...")
        AHI2(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle continue question
- **Next**: Routes to AHK1 (skip) or AHI2 (continue)

**AHI2** (Lines 1218-1224) - Send Rich Link
```python
def AHI2(usr):
    sendRichlink(AH_ID, usr.userId, "https://register.apple.com/resources/messages/...", "heroImage.png", "Apple Messages for Business")
    userStat = awkStop(usr.userId, "AHI3", 4)  # Wait 4 seconds
    if userStat != "stop":
        AHI3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send rich link example
- **Next**: Routes to AHI3

**AHI3** (Lines 1225-1231) - Photo Transition
```python
def AHI3(usr):
    sendMessage(AH_ID, usr.userId, "Earlier we sent you a photo.")
    userStat = awkStop(usr.userId, "AHI4", 2)
    if userStat != "stop":
        AHI4(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Transition to photo sharing
- **Next**: Routes to AHI4

**AHI4** (Lines 1232-1238) - Ask for Photo
```python
def AHI4(usr):
    sendMessage(AH_ID, usr.userId, f"{userName} will you share a picture of your favorite food?")
    sendInteractive(AH_ID, usr.userId, "qr_photo.json", usr.lang)
    dbLastMessage(usr.userId, "AHJ1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Ask user to share photo (Yes/No)
- **Next**: Routes to AHJ1

**AHJ1** (Lines 1240-1254) - Photo Response
```python
def AHJ1(usr):
    if usr.selection == 0:  # Yes
        sendMessage(AH_ID, usr.userId, "Awesome! We will hang tight while you send your fav.")
        dbLastMessage(usr.userId, "AHJ1")  # Stay in this state to wait for photo
    else:  # No
        sendMessage(AH_ID, usr.userId, "Or... just send a photo anytime")
        AHJ2(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Handle photo sharing response
- **Next**: Wait for photo upload or continue to AHJ2

**AHJ2** (Lines 1255-1263) - Send Documents
```python
def AHJ2(usr):
    sendMessage(AH_ID, usr.userId, "In Business Chat, we can also share documents...")
    sendFile(AH_ID, usr.userId, "metrics.numbers")
    if userStatus(usr.userId) != "stop":
        AHJ3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send Numbers document
- **Next**: Routes to AHJ3

**AHJ3** (Lines 1264-1271) - Send PDF
```python
def AHJ3(usr):
    sendFile(AH_ID, usr.userId, "document.pdf")
    if userStatus(usr.userId) != "stop":
        AHJ4(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send PDF document
- **Next**: Routes to AHJ4

**AHJ4** (Lines 1272-1278) - Learn More Question
```python
def AHJ4(usr):
    sendMessage(AH_ID, usr.userId, f"{userName}, would you like to learn more about Business Chat?")
    sendInteractive(AH_ID, usr.userId, "qr_learn_more.json", usr.lang)
    dbLastMessage(usr.userId, "AHK1")
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Ask about learning more
- **Next**: Routes to AHK1

---

#### **Phase 6: Summary & Wrap-up (AHK1 → AHK3)**

**AHK1** (Lines 1280-1288) - Send Summary
```python
def AHK1(usr):
    if usr.selection == 0:  # Yes
        sendMessage(AH_ID, usr.userId, "Please connect with your Apple rep...")
    sendMessage(AH_ID, usr.userId, "We've thrown a handful of Messages features at you today...")
    menu_summary(usr)  # Send summary list picker
    userStat = awkStop(usr.userId, "AHK2", 12)
    if userStat != "stop":
        AHK2(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send summary list picker with all features
- **Next**: Routes to AHK2

**AHK2** (Lines 1289-1295) - Register Site Intro
```python
def AHK2(usr):
    sendMessage(AH_ID, usr.userId, "A great first step will be to visit our Register site...")
    if userStatus(usr.userId) != "stop":
        AHK3(usr)
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Transition to register site
- **Next**: Routes to AHK3

**AHK3** (Lines 1296-1302) - Final Message
```python
def AHK3(usr):
    sendRichlink(AH_ID, usr.userId, "https://register.apple.com/business-chat", "heroImage.png", "Apple Messages for Business")
    sendMessage(AH_ID, usr.userId, "We will get back to you soon 😀")
    dbLastMessage(usr.userId, "AH-restart")  # Flow complete
```
- **n8n Status**: ❌ Not implemented
- **Purpose**: Send register site rich link, end flow
- **End State**: Flow complete

---

## Text Message Handlers (from messageList line 150-200)

### ❌ COMPLETELY MISSING from n8n

| Keyword | Handler Function | Line | Purpose |
|---------|------------------|------|---------|
| `menu` | receivedMenu | 713 | Send main menu list picker |
| `startover` / `start over` | receivedStartOver | 718 | Send start over menu |
| `stop` | receivedStop | 709 | Stop all messages |
| `summary` | menu_summary | 573 | Send summary list picker |
| `time picker` / `timepicker` | send_timePicker / menu_timePicker | 359 / 364 | Time picker flows |
| `list picker` / `listpicker` | menu_listpicker | 327 | Send guitar list |
| `rich link` | richlinkSQA | 698 | Rich link demo |
| `wallet` | menu_wallet | 652 | Send .pkpass file |
| `apple pay` | menu_Apple_Pay | 339 | Direct Apple Pay |
| `authenticate` / `authentication` | menu_authenticate | 380 | Authentication flow |
| `location` / `locator` | menu_location | 657 | Store locator |
| `airport` | menu_airport | 693 | Airport rich link |
| `imessageapp` / `imessageextextension` | receivediMessageApp | 723 | Shazam extension |
| `shopify buy` / `shopify flow` | menu_shopify | 283 | Shopify integration |
| `content payload` | menu_content | 705 | Content payload demo |
| `native auth` | send_native_auth | 387 | Native auth |
| `server fail` / `server response` / `server unknown` | send_ss_* | 391-402 | Server auth states |
| `micro link` / `micro map` / `micro clip` / `micro region` / `micro custom` / `micro auto` | micro_* | 404-472 | Rich link micro service |
| `survey` | send_csat | 907 | CSAT survey |
| `quick reply` | send_qr | 912 | Quick reply demo |
| `request shack bia` | send_bia_form | 474 | BIA form |
| `business update` | send_update | 478 | Business update |
| `no icon` | imessage_app_no_icon | 585 | iMessage app no icon |
| `qa2 rich` / `qa2 maps` | qa2_* | 593-609 | QA rich links |
| `blast` / `blast rich` | blastdoor_* | 611-645 | Blastdoor testing |
| `apple pay no support` | apple_pay_no_support | 647 | Apple Pay unsupported |
| `talk to me goose` | goose_gif | 903 | Send goose GIF |

**Summary**: 0/40+ text handlers implemented

---

## Menu Functions from requestMenu (line 300-306)

### ❌ COMPLETELY MISSING from n8n

**requestMenu** handles main menu list picker selections:

```python
menuList = {
    "1.": menu_intent1,      # Set up Intent ID
    "2.": menu_listpicker,   # Guitar list picker ✅ EXISTS IN N8N
    "3.": menu_AR,           # Send AR file
    "4.": menu_Apple_Pay,    # Send Apple Pay ⚠️ EXISTS IN N8N
    "5.": menu_timePicker,   # Time picker ⚠️ EXISTS IN N8N
    "6.": menu_form,         # "Help Me Decide" form
    "7.": menu_image,        # Send image/selfie
    "8.": menu_documents,    # Send documents
    "9.": menu_authenticate, # Authentication
    "10": menu_imessageapp,  # iMessage app
    "11": menu_wallet,       # Wallet pass
    "12": menu_location      # Store locator
}
```

**n8n Current Menu**: Only routes to 4 options (guitar, time, location, features), missing 8 menu items

---

## Special Handler Functions

### Store & Location (Lines 1324-1340)

**findStores(usr)** - ❌ MISSING
- Purpose: Use KDTree spatial search to find 5 nearest Apple Stores
- Inputs: User coordinates (lat/long)
- Outputs: Sends store list picker OR time picker if no stores found

**requestStore(usr)** (Lines 748-754) - ❌ MISSING
- Purpose: Handle store selection from list picker
- Action: Send time picker for selected store

**requestGeoCode(usr)** (Lines 737-746) - ❌ MISSING
- Purpose: Handle geocode selection (when multiple matches)
- Action: Extract coordinates, call findStores

### Attachment Handlers (Lines 1304-1321)

**receivedAttachments(usr)** - ❌ MISSING
- Purpose: Download and process user photo uploads
- Actions:
  - Download image/file
  - Respond based on file type (.png, .jpg, .numbers, .gif)
  - Continue flow to AHJ2 if in photo sharing state (AHI/AHJ)
  - Handle location cards (filell: format)

### Authentication (Lines 808-845)

**requestIdAuth(usr)** (Lines 808-817) - ❌ MISSING
- Purpose: Process LinkedIn OAuth response
- Action: Extract user data, display name/headline

**serverSideResponse(usr)** (Lines 829-839) - ❌ MISSING
- Purpose: Handle server-side authentication completion
- Action: Retrieve stored auth data, display to user

**sendAuthStatus(usr)** (Lines 841-845) - ❌ MISSING
- Purpose: Display authentication status
- Action: Show auth success/failure message

### Start Over (Lines 794-806)

**requestIdStartOver(usr)** - ❌ MISSING
- Purpose: Secret menu to restart flow
- Options:
  1. "With Good Intentions" → restart flow
  2. "Ask for My Name" → restart with name prompt
  3. "Skip to the Summary" → send summary image
  4. "Delete My Record" → delete user, start fresh

### State Catchers (Lines 1013-1190)

**Purpose**: Handle users stuck on interactive elements with incremental prompting

**AHC1** (Lines 1013-1035) - Guitar Picker Catcher
- Counter: 2+ = prompt, 3+ = resend, 5+ = auto-select and continue

**AHF1** (Lines 1097-1109) - Apple Pay Catcher
- Counter: 2+ = skip payment, continue to lesson

**AHG1** (Lines 1130-1166) - Location Catcher
- Processes zipcode OR Apple Maps link
- Geocodes location
- Sends store list OR time picker

**AHH1** (Lines 1168-1190) - Time Picker Catcher
- Counter: 2+ = prompt, 3+ = resend, 5+ = skip lesson

---

## Current n8n Workflow Analysis

### What's Implemented (30 nodes total)

**✅ Fully Implemented (3 features)**:
1. **Guitar List → Guitar Selection → Guitar Image**
   - AMB Guitar List (template 329)
   - Parse Guitar Selection (Code)
   - Send Guitar Image (template 344)

2. **AR Prompt (Single Question)**
   - AMB AR Prompt (Quick Reply)
   - Parse AR Response (Code)
   - Is AR Yes? (IF)
   - Send AR File (template 344) OR AR No Message (HTTP)

3. **Apple Pay**
   - AMB Apple Pay Request (with line items)

**⚠️ Partially Implemented (5 features)**:
1. **Main Menu** - Template 341 only, missing routing to 8/12 menu options
2. **Time Picker** - Template 5 only, missing store selection flow
3. **Location Request** - Message only, missing geocoding and store list
4. **Features Summary** - Inline list picker, not template-based
5. **Apple Pay Response** - Missing requestIdApplePay handler

**❌ Completely Missing (20+ features)**:
- Complete demo flow (AHA1 → AHK3)
- Region selection
- "Help Me Decide" form
- Name collection
- Two-question AR flow
- Lesson scheduling
- Store locator with geocoding
- Rich links
- Photo sharing
- Documents
- Summary list picker
- Authentication
- Start over menu
- Wallet pass
- iMessage app integration
- Shopify integration
- All text message handlers
- All state catchers
- Attachment handlers

---

## n8n vs Python Feature Matrix

| Feature Category | Python Functions | n8n Status | Missing Count |
|------------------|------------------|------------|---------------|
| **Main Demo Flow** | 24 states (AHA1-AHK3) | ❌ 0/24 | **24** |
| **Interactive Handlers** | 25 functions | ⚠️ 3/25 | **22** |
| **Text Handlers** | 40+ keywords | ❌ 0/40 | **40+** |
| **Menu Functions** | 12 options | ⚠️ 4/12 | **8** |
| **State Catchers** | 4 catchers | ❌ 0/4 | **4** |
| **Store/Location** | 3 functions | ❌ 0/3 | **3** |
| **Authentication** | 6 functions | ❌ 0/6 | **6** |
| **Rich Links** | 10+ functions | ❌ 0/10 | **10+** |
| **Documents/Files** | 5 functions | ❌ 0/5 | **5** |
| **Attachments** | 1 function | ❌ 0/1 | **1** |

**Total Missing**: ~130+ functions/states

---

## Critical Missing Connections

### 1. Flow State Machine
- **Python**: Uses `dbLastMessage(usr.userId, "STATE")` to track position in flow
- **n8n**: Has no state tracking mechanism, only keyword routing

### 2. User Data Persistence
- **Python**: PostgreSQL database with user table (name, region, guitar, intent, etc.)
- **n8n**: No user data storage

### 3. Wait States & Timeouts
- **Python**: `awkStop(userId, nextState, seconds)` for timed transitions
- **n8n**: No timing mechanism

### 4. Incremental Prompting
- **Python**: Counter system (`lastMessage.count("+")`) for stuck users
- **n8n**: No retry/prompt logic

### 5. Capability Detection
- **Python**: Checks `capability-list` for FORM, TIME_PICKER, etc.
- **n8n**: No capability detection

---

## Implementation Priority Recommendations

### **Tier 1: Core Demo Flow (Must Have)**
Essential for matching Python experience:

1. **Region Selection Flow** (AHA1, AHA2, AHA3)
   - Quick Reply for region
   - State storage
   - Route to form or text input

2. **Name Collection Flow** (AHB1, AHB2, AHB1_2, AHB3)
   - "Help Me Decide" form
   - Name selection quick reply
   - Text input fallback
   - Personalized greeting

3. **Complete AR Flow** (AHC2, AHC3, AHD1, AHE1)
   - Two-question AR experience
   - Conditional messaging based on responses
   - Proper state transitions

4. **Lesson Scheduling Flow** (AHF2, AHF3, AHG1)
   - Transition after Apple Pay
   - Location/zipcode request
   - Geocoding
   - Store list picker
   - Store-specific time picker

5. **Continue Flow** (AHH2, AHI1)
   - Post-lesson confirmation
   - Continue/skip decision point

### **Tier 2: Content & Features (Should Have)**

6. **Rich Links Flow** (AHI2, AHI3, AHI4)
   - Rich link examples
   - Photo sharing request

7. **Documents Flow** (AHJ1, AHJ2, AHJ3, AHJ4)
   - Photo upload handling
   - Numbers document
   - PDF document
   - Learn more question

8. **Summary & Wrap-up** (AHK1, AHK2, AHK3)
   - Summary list picker with file sending
   - Register site rich link
   - Flow completion

### **Tier 3: Menu Enhancements (Could Have)**

9. **Complete Menu Routing**
   - Route all 12 menu options
   - Intent ID setup
   - AR direct access
   - Form direct access
   - Image/selfie
   - Documents
   - Authentication
   - iMessage app
   - Wallet
   - Store locator

10. **Text Message Handlers**
    - Keyword routing for all 40+ keywords
    - Start over menu
    - Stop functionality
    - Direct access to all features

### **Tier 4: Advanced Features (Nice to Have)**

11. **State Catchers**
    - Guitar picker catcher (AHC1)
    - Apple Pay catcher (AHF1)
    - Time picker catcher (AHH1)
    - Incremental prompting logic

12. **Authentication Flows**
    - LinkedIn OAuth
    - Server-side auth
    - Native auth
    - Auth status display

13. **Store Locator**
    - Geocoding service integration
    - KDTree spatial search
    - Store list picker
    - Multi-result handling

14. **Rich Link Features**
    - Rich link micro service
    - Maps links
    - App Clip links
    - Region-specific links

15. **Special Integrations**
    - Shopify flow
    - Business Initiated Auth (BIA)
    - CSAT survey
    - iMessage extensions

---

## Technical Requirements for Full Implementation

### Database Schema
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  last_message VARCHAR(50),
  capabilities TEXT[],
  guitar VARCHAR(255),
  region VARCHAR(50),
  intent VARCHAR(255),
  lang VARCHAR(10),
  stop_status BOOLEAN,
  last_interaction TIMESTAMP
);
```

### n8n Architecture Needs

1. **State Management Node**
   - Read/write user state to DB
   - Track flow position (AHA1, AHB2, etc.)
   - Increment counter logic

2. **User Data Node**
   - Store/retrieve name, region, guitar selection
   - Capability detection
   - Intent tracking

3. **Geocoding Service Node**
   - Integrate geocoding API
   - Handle multiple results
   - Return coordinates

4. **Store Search Node**
   - Query store database
   - Spatial search (nearest 5)
   - Return store list

5. **File Upload Handler**
   - Download attachments
   - Process images
   - Route to appropriate flow state

6. **Wait/Timeout Nodes**
   - Delay execution
   - Check user status
   - Auto-advance or stay

7. **Rich Link Node**
   - Generate rich link metadata
   - Send rich link messages
   - Handle video rich links

---

## Conclusion

**Current Implementation**: ~20% complete

**What Exists**:
- Basic menu routing (4/12 options)
- Guitar selection with image
- Single AR prompt
- Apple Pay request
- Time picker (standalone)

**What's Missing**:
- Complete sequential demo flow (24 states)
- 80% of interactive handlers
- 100% of text handlers
- 67% of menu options
- All state catchers
- All authentication
- All rich links
- All documents
- Store locator
- Geocoding
- User data persistence
- State machine
- Attachment handling

**To Achieve Parity**: Need ~110 additional nodes implementing 130+ missing functions

---

## Next Steps

1. **Decide on Scope**: Full parity vs. core demo only vs. menu-driven only
2. **Database Setup**: User tracking, state management, data persistence
3. **Phase 1 Implementation**: Core demo flow (AHA1 → AHK3) - ~50 nodes
4. **Phase 2 Implementation**: Menu routing completion - ~30 nodes
5. **Phase 3 Implementation**: Text handlers and advanced features - ~30 nodes

**Estimated Total**: 140-150 nodes for full parity with Python implementation
