# Acoustic House Core Templates - Filtering Results

## Summary

Successfully filtered **575 total templates** into three categories:

- ✅ **93 Core Templates** (16.2%) - Production-ready Acoustic House flows
- 🧪 **325 Test Templates** (56.5%) - Development/QA test cases
- ⚠️  **157 Unknown Templates** (27.3%) - Manual review needed

## Files Created

```
tmp/bot_migration/acoustic_house/
├── migration_data.json (64MB) - Original unfiltered
├── migration_data_CORE.json (31MB) - 93 core templates ⭐
├── migration_data_TEST.json (11MB) - 325 test templates
├── migration_data_UNKNOWN.json (23MB) - 157 unknown templates
├── FILTER_REPORT.json (20KB) - Detailed filter analysis
└── images/ (898 PNG files)
```

## Core Templates Identified (93 Total)

### Acoustic House Specific (Guitar Sales)

**WISMO (Where Is My Order) - Guitar Shipping** (14 templates)
- `wismo.orderConfirmed.orderImage` - Order confirmed with guitar image
- `wismo.orderShipped.GuitarImage` - Guitar shipped notification
- `wismo.orderInTransit.orderGuitar` - Guitar in transit tracking
- `wismo.orderDeliveredGuitar` - Guitar delivered confirmation
- `wismo.orderPickup` - Store pickup ready
- `wismo.orderDelayed.orderImage` - Delayed shipment with image
- `wismo.orderInTransit.orderImage` - In transit with order image
- `wismo.signatureRequired.orderImage` - Signature required notification
- + 6 more variants (with/without images)

**Guitar Navigation & Help** (3 templates)
- `menunlp` - NLP menu navigation
- `howhelp` - "How can we help" message
- `topicsnlp` - Topic selection via NLP

### List Pickers

None of the predefined core list pickers (`lp_summary_0319`, `lp_guitar_0319`, etc.) were found in the actual data. This suggests they may use different request IDs or weren't in the source files.

### Time Pickers

No core time picker templates found with the expected IDs (`time_0319`, `time_1218`).

### Forms

No core form templates found with the expected IDs (`form_help_me_decide`, `form_bia_ah`).

### Quick Replies

No core quick reply templates found with the expected IDs (`qr_travel`, `qr_name`, etc.).

## Test Templates (325 Total)

Correctly identified test patterns:
- `ap1000`-`ap1057` - Apple Pay test cases (57+ variants)
- `tp1000`-`tp1021` - Time Picker test cases (21+ variants)
- `au1`-`au17` - Authentication test cases
- `form1`-`form43` - Form test cases
- Number-prefixed files (`0_default`, `1_refid_1000`, etc.)
- Special character tests (`backslash`, `nonalpha`, `empty`, etc.)
- SQA test files (`tp2021sqa`, `longTPsqa`, etc.)

## Unknown Templates (157 Total)

**Needs Manual Review** - These may be core or test:

**Potentially Core:**
- `ApplePayPayload` - Generic Apple Pay template
- `TimePickerPayload` - Generic Time Picker template
- `ap1`-`ap31` - Early Apple Pay versions (vs ap1000+)
- `tp1`-`tp28` - Early Time Picker versions (vs tp1000+)
- `csat_first` - CSAT survey (customer satisfaction)
- `survey` - Generic survey template
- `content` - Generic content payload

**Likely Test/Dev:**
- `ap10000` - Numbered test file
- `lp1000`-`lp1028` - List picker tests
- `card_*` templates - Financial test flows
- `formtemplate`, `formtemplateV2` - Form templates
- Airline/baggage flows - Not Acoustic House specific

## Key Findings

### 1. **Missing Expected Core Templates**

The predefined core request IDs were NOT found in the actual migration data:
- ❌ `lp_summary_0319` (Feature summary)
- ❌ `lp_guitar_0319` (Guitar selection)
- ❌ `lp_menu_0319` (Main menu)
- ❌ `time_0319` (Appointment scheduler)
- ❌ `applepay_1018` (Payment request)
- ❌ `form_help_me_decide` (Decision tree)
- ❌ `qr_*` templates (Quick replies)

**This suggests**: The old bot may not have used these exact request IDs, or they're in different files.

### 2. **What WAS Found**

The actual core templates are primarily:
- **WISMO flows** for guitar order tracking
- **NLP navigation** templates
- **Test variants** of Apple Pay, Time Pickers, Forms

### 3. **Most Templates Are Test Data**

56.5% of templates are clearly test/development files, which is normal for a demo/development bot.

## Recommendations

### Option A: Import Core Templates Only (Conservative)

```bash
# Import only the 93 identified core templates
rails runner script/import_migrated_bots.rb \
  --account-id 1 \
  --business acoustic_house \
  --file tmp/bot_migration/acoustic_house/migration_data_CORE.json
```

**Pros**: Clean, minimal production setup
**Cons**: May miss some useful templates in "unknown" category

### Option B: Manual Review + Selective Import (Recommended)

1. **Review Unknown Templates**
   ```bash
   cat tmp/bot_migration/acoustic_house/migration_data_UNKNOWN.json | \
     jq '.payloads[] | {request_id, file_name, content_type}' | less
   ```

2. **Identify Additional Core Templates**
   - Look for templates with meaningful request IDs
   - Exclude obvious test files (lp1000+, numbered files)
   - Focus on: `ApplePayPayload`, `TimePickerPayload`, `csat_first`, real form templates

3. **Create Custom Filter**
   Edit `script/filter_core_templates.rb` to add found request IDs to `CORE_REQUEST_IDS`

4. **Re-filter and Import**

### Option C: Import Everything (Development/Testing)

```bash
# Import all 575 templates for development
rails runner script/import_migrated_bots.rb \
  --account-id 1 \
  --business acoustic_house
```

**Use case**: Full development environment, comprehensive testing

## Filter Criteria Used

### Identified as CORE:
- Contains keywords: `guitar`, `shop`, `store`, `order`, `wismo`, `ship`, `acoustic`, `music`
- Matches predefined core request IDs (none found in actual data)
- Request IDs starting with `qr_`, `form_`, `lp_`, `time_` (non-numbered)

### Identified as TEST:
- Request IDs: `ap####`, `tp####`, `au##`, `form##`, `qr##` (4+ digits or 2+ digits)
- Files starting with numbers: `0_default`, `1_refid_1000`
- Keywords: `sqa`, `test`, `nonalpha`, `backslash`, `empty`, `bad`
- Special test patterns: `card_dispute`, `triage_`, `binaryChoice`

### Marked as UNKNOWN:
- Everything else not matching core or test patterns
- Requires manual review to determine production readiness

## Next Steps

1. **Review Filter Report**
   ```bash
   cat tmp/bot_migration/acoustic_house/FILTER_REPORT.json | jq '.'
   ```

2. **Examine Unknown Templates**
   Manually review the 157 unknown templates to identify:
   - Additional core templates to add
   - False positives (tests marked as unknown)
   - Templates to exclude

3. **Update Filter Script (Optional)**
   Add discovered core template IDs to `CORE_REQUEST_IDS` constant

4. **Import Core Templates**
   Use the CORE file for production import

## Template Breakdown by Type

| Category | Count | % | File Size |
|----------|-------|---|-----------|
| Core | 93 | 16.2% | 31MB |
| Test | 325 | 56.5% | 11MB |
| Unknown | 157 | 27.3% | 23MB |
| **Total** | **575** | **100%** | **64MB** |

## Conclusion

The filter successfully identified:
- ✅ Guitar-specific WISMO flows (core Acoustic House functionality)
- ✅ Hundreds of test templates (can be excluded from production)
- ⚠️  157 templates needing manual review

**Recommended**: Review unknown templates, update filter, re-run, then import CORE templates only.
