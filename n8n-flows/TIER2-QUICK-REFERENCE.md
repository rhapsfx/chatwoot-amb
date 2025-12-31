# Tier 2 Flows - Quick Reference

## File Locations

```
/Users/rhaps/LocalGit/chatwoot/n8n-flows/
├── Acoustic-House-Bot-WITH-TIER2.json          # ← IMPORT THIS FILE
├── add_tier2_flows.py                           # Python generator script
├── Acoustic-House-Bot-TIER2-IMPLEMENTATION.md   # Implementation tracking
├── Acoustic-House-Bot-TIER2-FLOW-DIAGRAM.md     # Complete flow diagram
└── TIER2-IMPLEMENTATION-SUMMARY.md              # This summary
```

## Quick Stats

- **117 nodes** (was 92, +25 new)
- **96 connections** (was 72, +24 new)
- **3 new flows**: Rich Links, Documents, Summary
- **6 new routes**: continue_yes/no, photo_yes/no, learn_more_yes/no

## Import Steps

1. Open n8n → Workflows
2. Click "Import from File"
3. Select: `Acoustic-House-Bot-WITH-TIER2.json`
4. Verify 117 nodes loaded
5. Create 4 templates (see below)
6. Test and deploy

## Required Templates

| ID | Type | Name | Purpose |
|----|------|------|---------|
| 7 | Rich Link | Apple Docs Link | https://register.apple.com/resources/messages/messaging-documentation/ |
| 8 | File | Numbers File | metrics.numbers |
| 9 | File | PDF File | document.pdf |
| 10 | List Picker | Summary | 13 features with images |

## Flow Paths

### Path 1: Continue Yes (Full Experience)
```
Continue Yes → Rich Link → Photo Question → Documents → Summary → End
```

### Path 2: Continue No (Skip to Summary)
```
Continue No → Summary → End
```

### Path 3: Photo Yes (Wait for Upload)
```
Photo Yes → "Awesome! We will hang tight..." → Documents
```

### Path 4: Photo No (Continue Anyway)
```
Photo No → "Or... just send a photo anytime" → Documents
```

### Path 5: Learn More (Either Answer)
```
Learn More Yes/No → Summary → End
```

## New Nodes Added

### Tier 2.1: Rich Links (8 nodes)
- Is Continue Response?
- AHI1 - Continue Yes?
- AHI2 - Transition Message
- AHI2 - Rich Link (Apple Docs)
- AHI3 - Photo Transition
- AHI4 - Ask for Photo
- AHI4 - Photo Quick Reply
- Set State: photo_asked

### Tier 2.2: Documents (10 nodes)
- Is Photo Response?
- AHJ1 - Photo Yes?
- AHJ1 - Wait for Photo
- AHJ1 - Send Anytime
- AHJ2 - Documents Intro
- AHJ2 - Send Numbers File
- AHJ3 - Send PDF
- AHJ4 - Learn More Question
- AHJ4 - Learn More Quick Reply
- Set State: learn_more_asked

### Tier 2.3: Summary (7 nodes)
- Is Summary Route?
- AHK1 - Summary Intro
- AHK1 - Summary List Picker
- AHK2 - Register Site Intro
- AHK3 - Register Rich Link
- AHK3 - Final Message
- Set State: flow_complete

## Testing Checklist

- [ ] Import JSON successfully
- [ ] All 117 nodes present
- [ ] All connections valid
- [ ] Create Template 7 (Rich Link)
- [ ] Create Template 8 (Numbers file)
- [ ] Create Template 9 (PDF file)
- [ ] Create Template 10 (Summary List Picker)
- [ ] Test: Continue Yes path
- [ ] Test: Continue No path
- [ ] Test: Photo Yes branch
- [ ] Test: Photo No branch
- [ ] Test: Learn More Yes
- [ ] Test: Learn More No
- [ ] Verify: All bot states set correctly
- [ ] Verify: Final message appears
- [ ] Verify: flow_complete state set

## Bot States

New states added:
- `continue_asked`
- `rich_links_start`
- `photo_asked`
- `waiting_photo`
- `documents_start`
- `learn_more_asked`
- `summary_start`
- `flow_complete`

## Quick Troubleshooting

### JSON won't import
- Verify file is valid JSON: `python3 -m json.tool file.json`
- Check n8n version compatibility
- Try re-generating with Python script

### Templates not working
- Verify template IDs match (7, 8, 9, 10)
- Check template content in Chatwoot admin
- Ensure files are uploaded and accessible

### Routing issues
- Check bot_state is being set
- Verify quick reply identifiers match exactly
- Enable console logging in Router node

### Nodes disconnected
- Check connections section in JSON
- Verify node IDs match
- Re-import or manually connect

## Support

For issues or questions:
1. Check the complete flow diagram: `Acoustic-House-Bot-TIER2-FLOW-DIAGRAM.md`
2. Review implementation details: `Acoustic-House-Bot-TIER2-IMPLEMENTATION.md`
3. Read full summary: `TIER2-IMPLEMENTATION-SUMMARY.md`
4. Examine Python script: `add_tier2_flows.py`

## Success Indicators

✅ All nodes load without errors
✅ Router recognizes new routes
✅ Templates render correctly
✅ All paths reach Summary flow
✅ Final message displays
✅ Bot state = flow_complete
✅ Can restart and run again

---

**Ready to Deploy**: After testing passes all checkboxes above
