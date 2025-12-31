# Acoustic House Bot - Python Logic Implementation

## ✅ All Changes Complete!

Based on analysis of `_apple/Acoustic-House-Bot-origin/acoustichouse/AH.py`, the n8n workflow has been updated to match the original Python implementation logic.

---

## Changes Made

### 1. AMB Main Menu - Template 341 ✅

**Before**:
```json
{
  "templateId": 1,
  "title": "What would you like to do?",
  "sections": { /* 47 lines of custom configuration */ }
}
```

**After**:
```json
{
  "templateId": 341
}
```

**Why**: Template-based approach (all configuration in Chatwoot template 341)

---

### 2. AMB Guitar List - Template 329 ✅

**Before**:
```json
{
  "templateId": 2,
  "title": "🎸 Here's our premium guitar collection:",
  "sections": { /* 75 lines of guitar data */ }
}
```

**After**:
```json
{
  "templateId": 329
}
```

**Why**: Template-based approach (all guitar data in Chatwoot template 329)

---

### 3. Guitar List Selection Logic ✅

**Added Nodes**:

#### 3.1 Parse Guitar Selection (Code Node)
**Purpose**: Extract guitar selection from List Picker interactive response

**Logic** (from Python line 756-787):
```python
def requestIdGuitar(usr):
    guitarList = {"Gibson Les Paul R8": "GibsonLesPaul2.jpg", ...}
    sendFile(AH_ID, usr.userId, guitarList[usr.selection])
```

**n8n Implementation**:
```javascript
const interactive = contentAttrs.interactive_data?.data?.['list-picker'] || {};
const selected = interactive.selectedItems?.[0] || {};
const guitarIdentifier = selected.identifier || '';
const guitarTitle = selected.title || '';
```

**Outputs**:
- `guitarIdentifier`: e.g., "guitar_gibson_j45"
- `guitarTitle`: e.g., "Gibson J-45"
- `conversationId`, `accountId`

#### 3.2 Send Guitar Image (Template Message Node)
**Type**: `CUSTOM.chatwootAMBTemplateMessage`
**Template ID**: 344
**Purpose**: Send guitar image file based on selection

**Based on**: Python line 770 - `sendFile(AH_ID, usr.userId, guitarList[usr.selection])`

---

### 4. AR Prompt Response Logic ✅

**Added Nodes**:

#### 4.1 Parse AR Response (Code Node)
**Purpose**: Extract AR Quick Reply response (Yes/No)

**Logic** (from Python lines 1056-1087):
```python
def AHD1(usr):
    if usr.selection == 0:  # Yes
        # Continue with AR flow
    else:  # No
        # Show message but continue
```

**n8n Implementation**:
```javascript
const identifier = interactive.identifier || '';
const isYes = identifier === 'ar_yes';  // ar_yes = Yes, ar_no = No

return {
  json: {
    arResponse: identifier,
    isArYes: isYes,
    isArNo: !isYes
  }
};
```

#### 4.2 Is AR Yes? (IF Node)
**Purpose**: Route based on AR response
- **True path**: User selected "Yes" → Send AR file
- **False path**: User selected "No" → Show message

#### 4.3 Send AR File (Template Message Node)
**Type**: `CUSTOM.chatwootAMBTemplateMessage`
**Template ID**: 344
**Triggered**: When user selects "Yes" on AR prompt

**Based on**: Python line 1041 - `sendFile(AH_ID, usr.userId, "stratocaster.usdz")`

#### 4.4 AR No Message (HTTP Request Node)
**Purpose**: Send instructional message when user selects "No"
**Message**: "Try tapping on the image to see the AR image of the guitar!"

**Based on**: Python line 1081 - `sendMessage(AH_ID, usr.userId, findMsg("arguitar_1_2", usr.lang))`

---

## Updated Workflow Flow

### Complete Guitar → AR → Apple Pay Flow:

```
Guitar List (Template 329)
  ↓
Parse Guitar Selection (Code)
  ↓
Send Guitar Image (Template 344)
  ↓
AMB AR Prompt (Quick Reply)
  ↓
Parse AR Response (Code)
  ↓
Is AR Yes? (IF)
  ├─ True  → Send AR File (Template 344)
  └─ False → AR No Message (HTTP)
  ↓
AMB Apple Pay Request
```

**Key Points**:
1. **Guitar selection captured**: Parses List Picker response
2. **Guitar image sent**: Uses template 344
3. **AR response captured**: Parses Quick Reply response
4. **Conditional logic**: Different actions for Yes/No
5. **Both paths converge**: Both go to Apple Pay

---

## Template Requirements

### Chatwoot Templates Needed:

| Template ID | Type | Purpose | Content |
|-------------|------|---------|---------|
| **341** | List Picker | Main Menu | 4 options: Browse Guitars, Book Appointment, Find Store, Features |
| **329** | List Picker | Guitar List | Multiple guitar models with images |
| **344** | File/Template Message | File Sending | Sends guitar images OR AR files |

### Template 344 Usage:

Template 344 is used for **both** guitar images and AR files:
1. **After Guitar Selection**: Sends guitar image (e.g., GibsonLesPaul2.jpg)
2. **After AR Yes Response**: Sends AR file (e.g., stratocaster.usdz)

**Configuration Needed**: Template 344 should support dynamic file selection based on context.

---

## Python → n8n Logic Mapping

### Guitar List Logic

**Python** (`requestIdGuitar`, line 756-787):
```python
guitarList = {
    "Gibson Les Paul R8": "GibsonLesPaul2.jpg",
    "Martin DC28E Dreadnought": "MartinDC28EDreadnought2.jpg",
    ...
}
sendFile(AH_ID, usr.userId, guitarList[usr.selection])
```

**n8n**:
```
Parse Guitar Selection (extracts guitarIdentifier)
  ↓
Send Guitar Image (template 344 with guitarIdentifier)
```

### AR Prompt Logic

**Python** (`AHD1` → `AHE1`, lines 1056-1087):
```python
def AHD1(usr):
    if usr.selection == 0:  # Yes
        # User viewed AR, continue
    else:  # No
        sendMessage(AH_ID, usr.userId, "Try tapping on the image...")
    # Both paths continue to Apple Pay
```

**n8n**:
```
Parse AR Response
  ↓
Is AR Yes? (IF)
  ├─ True  → Send AR File
  └─ False → AR No Message
  ↓
Both → Apple Pay
```

---

## Node Count

**Before**: 24 nodes
**After**: 30 nodes (+6 new nodes)

### New Nodes:
1. Parse Guitar Selection
2. Send Guitar Image
3. Parse AR Response
4. Is AR Yes?
5. Send AR File
6. AR No Message

---

## Connection Updates

### Added Connections:

```
"AMB Guitar List" → "Parse Guitar Selection"
"Parse Guitar Selection" → "Send Guitar Image"
"Send Guitar Image" → "AMB AR Prompt"
"AMB AR Prompt" → "Parse AR Response"
"Parse AR Response" → "Is AR Yes?"
"Is AR Yes?" → "Send AR File" (true)
"Is AR Yes?" → "AR No Message" (false)
"Send AR File" → "AMB Apple Pay Request"
"AR No Message" → "AMB Apple Pay Request"
```

---

## Testing Guide

### Test 1: Complete Flow
1. **Send**: "start"
2. **Select**: Main Menu → "Browse Guitars"
3. **Select**: Guitar → "Gibson J-45"
4. **Verify**: Guitar image sent (Template 344)
5. **Select**: AR Prompt → "Yes"
6. **Verify**: AR file sent (Template 344)
7. **Verify**: Apple Pay displayed

### Test 2: AR "No" Path
1. Follow steps 1-4 above
2. **Select**: AR Prompt → "No"
3. **Verify**: Message "Try tapping on the image to see the AR image of the guitar!"
4. **Verify**: Apple Pay displayed (no AR file sent)

### Test 3: Template-Based Main Menu
1. **Send**: "start"
2. **Verify**: Main Menu from Template 341 displays
3. **Verify**: 4 options visible

### Test 4: Template-Based Guitar List
1. Select "Browse Guitars" from Main Menu
2. **Verify**: Guitar List from Template 329 displays
3. **Verify**: Multiple guitar models with images

---

## Configuration Requirements

### Chatwoot Setup:

1. **Template 341 (Main Menu)**:
   - Type: List Picker
   - Sections: 1
   - Items: 4 (Browse Guitars, Book Appointment, Find Store, Features)

2. **Template 329 (Guitar List)**:
   - Type: List Picker
   - Sections: 3 (Martin, Taylor, Gibson)
   - Items per section: 2-3 guitars
   - Include images for each guitar

3. **Template 344 (File Sending)**:
   - Type: File/Template Message
   - Support dynamic file selection
   - Files needed:
     - Guitar images: GibsonLesPaul2.jpg, MartinDC28EDreadnought2.jpg, etc.
     - AR files: stratocaster.usdz

### n8n Setup:

1. **Credentials**:
   - `chatwootBotApi`: Assigned to all AMB nodes
   - `httpHeaderAuth`: Manually assign to HTTP Request nodes

2. **Custom Nodes Required**:
   - `CUSTOM.chatwootAMBListPicker`
   - `CUSTOM.chatwootAMBQuickReply`
   - `CUSTOM.chatwootAMBTemplateMessage`
   - `CUSTOM.chatwootAMBApplePay`
   - `CUSTOM.chatwootAMBTimePicker`

---

## Verification Checklist

- [x] AMB Main Menu uses template 341
- [x] AMB Guitar List uses template 329
- [x] Guitar List selection captured
- [x] Guitar image sent after selection
- [x] AR Prompt response captured
- [x] AR "Yes" → Send AR file
- [x] AR "No" → Show message
- [x] Both AR paths → Apple Pay
- [x] All connections updated
- [x] JSON syntax valid
- [x] 30 nodes total

---

## Python Code References

### Key Functions Analyzed:

1. **`requestIdGuitar`** (line 756-787): Guitar selection handling
2. **`AHD1`** (line 1056-1072): AR prompt first question
3. **`AHE1`** (line 1073-1087): AR prompt response handling
4. **`requestMenu`** (line 300-306): Main menu list picker
5. **`menu_listpicker`** (line 327-330): Guitar list picker

### Interactive Request IDs:

- **`lp_guitar_0319`**: Guitar List Picker (line 95)
- **`lp_menu_0319`**: Main Menu Picker (line 102)
- **`qr_view_ar`**: AR view question (line 89)
- **`qr_place_ar`**: AR placement question (line 90)

---

## File Status

**File**: `Acoustic-House-Bot-MIGRATED.json`
**Size**: ~36KB (increased from ~34KB)
**Nodes**: 30 (increased from 24)
**Status**: ✅ Ready to import and test
**Compliance**: ✅ Matches Python logic from AH.py

---

## Next Steps

1. **Import workflow** into n8n
2. **Configure Chatwoot templates** (341, 329, 344)
3. **Assign credentials** to HTTP Request nodes
4. **Test complete flow** from "start" to Apple Pay
5. **Verify AR Yes/No paths** work correctly
6. **Confirm file sending** (guitar images and AR files)

All logic from the original Python implementation has been successfully translated to the n8n workflow!
