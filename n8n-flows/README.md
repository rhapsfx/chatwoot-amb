# n8n Flows - Acoustic House Bot

## 🚀 Quick Start

**Want to deploy the bot?** → Import `Acoustic-House-Bot-COMPLETE.json`

**Want to test routing?** → Import `Acoustic-House-Bot-DEBUG-MINIMAL.json`

**Need help?** → Read `COMPLETE-FLOW-SETUP-GUIDE.md`

---

## 📁 Files Index

### Production Flows
| File | Purpose | Status | Documentation |
|------|---------|--------|---------------|
| **Acoustic-House-Bot-COMPLETE.json** | Full production bot | ✅ Ready | COMPLETE-FLOW-SETUP-GUIDE.md |
| **Acoustic-House-Bot-DEBUG-MINIMAL.json** | Routing test | ✅ Ready | QUICK-REFERENCE.md |
| **Acoustic-House-Bot-IF-CHAIN-V2.json** | Simplified bot | ✅ Ready | START-HERE.md |

### Documentation
| File | Description |
|------|-------------|
| **START-HERE.md** | Overview and quick start guide |
| **COMPLETE-FLOW-SETUP-GUIDE.md** | Comprehensive setup for production |
| **DATA-REFERENCING-FIX.md** | Important fix for data persistence in node chains |
| **FLOW-COMPARISON.md** | Compare all flows and choose |
| **QUICK-REFERENCE.md** | Quick commands cheat sheet |
| **ROUTING-DEBUG-GUIDE.md** | Troubleshooting routing issues |
| **ROUTING-ANALYSIS.md** | Technical analysis of routing evolution |
| **Acoustic-House-Bot-README.md** | Original documentation |

---

## 🎯 Choose Your Path

### Path 1: I want a production bot (Most Users)
```
1. Read: COMPLETE-FLOW-SETUP-GUIDE.md
2. Import: Acoustic-House-Bot-COMPLETE.json
3. Configure credentials
4. Test with "start" command
5. Customize and deploy
```

### Path 2: I'm having routing issues
```
1. Import: Acoustic-House-Bot-DEBUG-MINIMAL.json
2. Test with "time" and "hello"
3. If works → Import COMPLETE
4. If fails → Read ROUTING-DEBUG-GUIDE.md
```

### Path 3: I want to learn how it works
```
1. Read: START-HERE.md
2. Review: FLOW-COMPARISON.md
3. Import: DEBUG-MINIMAL (simplest)
4. Import: COMPLETE (full-featured)
5. Experiment and customize
```

---

## 📊 Feature Comparison

| Feature | COMPLETE | DEBUG-MINIMAL | IF-CHAIN-V2 |
|---------|:--------:|:-------------:|:-----------:|
| Production Ready | ✅ | ❌ | ⚠️ |
| Full Features | ✅ | ❌ | ⚠️ |
| Easy Testing | ⚠️ | ✅ | ⚠️ |
| Dependencies | None | None | Custom nodes |
| Routes | 14+ | 2 | 6 |
| Logging | ✅✅✅ | ✅✅✅ | ⚠️ |

---

## 🆘 Quick Help

**Bot not responding?**
1. Check workflow is active
2. Verify credentials assigned
3. Check webhook URL in Chatwoot
4. Read: COMPLETE-FLOW-SETUP-GUIDE.md

**Wrong route triggered?**
1. Test with DEBUG-MINIMAL first
2. Check execution logs in n8n
3. Read: ROUTING-DEBUG-GUIDE.md

**Need to customize?**
1. Read customization section in COMPLETE-FLOW-SETUP-GUIDE.md
2. Modify content in HTTP Request nodes
3. Test each change

---

## 📖 Documentation Reading Order

For best understanding:

1. **START-HERE.md** - Get oriented (15 min)
2. **FLOW-COMPARISON.md** - Choose your flow (10 min)
3. **COMPLETE-FLOW-SETUP-GUIDE.md** - Full setup (30 min)
4. **QUICK-REFERENCE.md** - Keep as reference

---

## ✨ What's Included in COMPLETE Flow

✅ Welcome flow with 2 messages
✅ Main menu (list picker with 4 options)
✅ Guitar catalog (6 guitars across 3 brands)
✅ AR experience prompt (quick reply)
✅ Apple Pay payment flow
✅ Time picker (dynamic 7-day slots)
✅ Appointment confirmation
✅ Location finder
✅ Features summary
✅ State management system
✅ Interactive response handling
✅ 14+ routes with extensive logging

---

## 🔧 Technical Details

### COMPLETE Flow
- **Nodes**: 30
- **Dependencies**: None (only standard n8n nodes)
- **Routing**: IF chain with boolean flags
- **Time Slots**: Dynamically generated
- **Interactive Messages**: All AMB types
- **State**: Tracked in custom_attributes

### DEBUG-MINIMAL Flow
- **Nodes**: 10
- **Purpose**: Test basic routing
- **Routes**: 2 (TIME vs OTHER)
- **Output**: Clear debug messages

---

## 📞 Support Resources

- **Setup Issues**: COMPLETE-FLOW-SETUP-GUIDE.md
- **Routing Issues**: ROUTING-DEBUG-GUIDE.md
- **Feature Questions**: FLOW-COMPARISON.md
- **Quick Commands**: QUICK-REFERENCE.md
- **Technical Details**: ROUTING-ANALYSIS.md

External:
- n8n Community: https://community.n8n.io/
- n8n Docs: https://docs.n8n.io/
- Chatwoot: Check your instance documentation

---

## 🎓 Learning Path

**Beginner**:
```
START-HERE.md → DEBUG-MINIMAL flow → Test basic routing
```

**Intermediate**:
```
FLOW-COMPARISON.md → COMPLETE flow → Customize content
```

**Advanced**:
```
ROUTING-ANALYSIS.md → COMPLETE flow → Add custom routes
```

---

## 🚦 Status

| Component | Status | Notes |
|-----------|--------|-------|
| COMPLETE Flow | ✅ Production Ready | All features working |
| DEBUG-MINIMAL | ✅ Stable | Testing tool |
| IF-CHAIN-V2 | ✅ Stable | Requires custom nodes |
| Documentation | ✅ Complete | All guides available |
| Testing | ✅ Verified | Works with n8n + Chatwoot |

---

## 📝 Recent Updates

- **2024**: Created COMPLETE flow with all features
- **2024**: Added comprehensive documentation suite
- **2024**: Created FLOW-COMPARISON.md for easy selection
- **2024**: Updated START-HERE.md with production path
- **2024**: Verified DEBUG-MINIMAL routing works

---

## 🎯 TL;DR

**Production Bot**: `Acoustic-House-Bot-COMPLETE.json` + `COMPLETE-FLOW-SETUP-GUIDE.md`

**Testing**: `Acoustic-House-Bot-DEBUG-MINIMAL.json` + `QUICK-REFERENCE.md`

**Help**: Read `START-HERE.md` first

---

*All flows tested and working with n8n + Chatwoot AMB*
*Status: Production Ready ✅*
