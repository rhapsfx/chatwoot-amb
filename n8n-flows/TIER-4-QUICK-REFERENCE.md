# Tier 4 Quick Reference Card

## At a Glance

**Status**: ✅ Complete (Demo/Placeholder)
**File**: `Acoustic-House-Bot-TIER4.json`
**Size**: 138 KB | **Nodes**: 130 | **New Nodes**: 38

---

## Import Workflow (3 Steps)

1. Open n8n → **Workflows**
2. Click **Import from File**
3. Select **`Acoustic-House-Bot-TIER4.json`** → **Activate**

---

## Test State Catchers (Works Now!)

### Guitar Picker Catcher ✅
```
Type: "start"
Select: "Browse Guitars"
DON'T select guitar → Wait
Result:
  - 2nd message: "Looks like we're waiting..."
  - 3rd message: Guitar list resent
  - 5th message: Auto-selects Martin DC28E
```

### Apple Pay Catcher ✅
```
Reach Apple Pay screen
DON'T tap Apple Pay → Wait
Result:
  - 3rd message: "Just kidding {name}!"
  - Continues to time picker
```

### Time Picker Catcher ✅
```
Reach time picker
DON'T select time → Wait
Result:
  - 2nd message: "Looks like we're waiting..."
  - 3rd message: Time picker resent
  - 5th message: "You must be a shredding pro!"
```

---

## Test Store Locator (Hardcoded Demo)

```
Type: "location"
Type: "94102" (SF zipcode)
Result: 5 stores displayed with distances
Select: Any store
Result: Time picker for selected store
```

**Other zipcodes**: 94103 (SF), 10001 (NY), 90210 (LA), 60601 (Chicago), 98101 (Seattle)

---

## Test Placeholders (Shows TODOs)

### Authentication
```
Type: "authenticate"
Result: Auth options → Select any → TODO message
```

### Rich Links
```
Type: "rich link"
Result: Website, Maps, App Clip examples + TODO
```

### Special Integrations
```
Type: "shopify"  → Shopify placeholder + TODO
Type: "bia"      → BIA placeholder + TODO
Type: "survey"   → CSAT survey (functional!)
Type: "imessage" → iMessage placeholder + TODO
```

---

## New Keywords (6)

| Keyword | Feature |
|---------|---------|
| `authenticate`, `auth`, `oauth` | Authentication |
| `rich link`, `rich links` | Rich Links |
| `shopify` | Shopify |
| `bia`, `business auth` | BIA |
| `survey`, `csat` | CSAT Survey |
| `imessage`, `imessage app` | iMessage |

---

## Features Summary

| Feature | Status | Nodes | Ready? |
|---------|--------|-------|--------|
| **State Catchers** | ✅ Functional | 18 | Yes - Deploy now |
| **Store Locator** | ⚠️ Hardcoded | 4 | Demo only |
| **Authentication** | 📋 Placeholder | 4 | Requires OAuth |
| **Rich Links** | 📋 Placeholder | 4 | Requires microservice |
| **Special Integrations** | 📋 Placeholder | 5 | Requires services |

---

## Production Timeline

| Phase | Feature | Days | Cost |
|-------|---------|------|------|
| **Phase 1** | State Catchers | 1-2 | $0 |
| **Phase 2** | Store Locator | 3-5 | $20/mo |
| **Phase 3** | Authentication | 5-7 | $0-30/mo |
| **Phase 4** | Rich Links | 4-6 | $7-25/mo |
| **Phase 5** | Special Integrations | 7-10 | $15-80/mo |
| **Total** | All Features | **20-30 days** | **$42-155/mo** |

*Plus $99/year Apple Developer account*

---

## Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| **TIER-4-SUMMARY.md** | Executive summary | 5 min |
| **TIER-4-IMPLEMENTATION-COMPLETE.md** | Implementation guide | 15 min |
| **TIER-4-IMPLEMENTATION-SPEC.md** | Technical spec | 20 min |
| **TIER-4-TODOS.md** | Production checklist | 10 min |
| **TIER-4-FILE-MANIFEST.md** | File inventory | 5 min |

---

## Troubleshooting

### State Catchers Not Working
- ✓ Check `bot_state` in custom_attributes
- ✓ Verify `retry_count` incrementing
- ✓ Check IF node conditions

### Store Locator Returns Error
- ✓ Use supported zipcodes: 94102, 10001, 90210, 60601, 98101
- ✓ Check `store-locator-geocode` node

### Placeholders Show Error
- ✓ Check router updated with Tier 4 keywords
- ✓ Verify HTTP Request nodes have credentials

---

## External Services Needed (Production)

1. **Geocoding** → Google Maps API, Apple Maps, or OSM
2. **Database** → PostgreSQL with PostGIS ($15-50/mo)
3. **Caching** → Redis ($0-30/mo)
4. **Microservice** → Heroku, Vercel ($7-25/mo)
5. **Apple Developer** → App Clip, Native Auth ($99/year)

---

## Next Steps

### Today
1. ✅ Import workflow
2. ✅ Assign credentials
3. ✅ Test state catchers
4. ✅ Test store locator
5. ✅ Review placeholders

### This Week
1. Decide production scope
2. Choose external services
3. Create project plan
4. Setup staging environment
5. Begin Phase 1 (tune state catchers)

### Next Month
1. Implement Phases 2-5
2. Integration testing
3. User acceptance testing
4. Production deployment
5. Monitor and iterate

---

## Success Metrics

### Demo ✅
- [x] 130 nodes implemented
- [x] State catchers functional
- [x] Store locator demo working
- [x] All placeholders documented

### Production 🎯
- [ ] External services integrated
- [ ] 95% uptime
- [ ] < 5s latency
- [ ] 90% user satisfaction
- [ ] < 1% error rate

---

## Support

**Questions?** See documentation:
- State Catchers → Nodes `ahc1-*`, `ahf1-*`, `ahh1-*`
- Store Locator → Nodes `store-locator-*`
- Auth/Rich Links/Integrations → Check TODO messages in placeholder nodes

**File Issues?** Check **TIER-4-FILE-MANIFEST.md**

---

**Version**: 4.0.0 | **Date**: 2025-01-10 | **Status**: ✅ Complete (Demo)
