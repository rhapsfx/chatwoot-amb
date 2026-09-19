# Bot Flow Builder — Implementation Progress

## Status: Phase 1 In Progress (Cleanup Migrations)

---

## Phase 1: Cleanup Migrations — **3–5 days** (In Progress)

### 1.1 Fix `agent_bot.bot_type` enum — ✅ COMPLETED
- **File**: `app/models/agent_bot.rb:41`
- **Change**: `{ webhook: 0, flow: 1 }`
- **Migration**: Add value 1 to enum (no existing rows use it)
- **Risk**: Low — value 1 is unused

### 1.2 Repurpose `bot_flows` table — ⬜ PENDING
- **Existing**: `db/schema.rb:408-426` (unused)
- **Plan**: Add partial unique index `(agent_bot_id) WHERE is_published`
- **Migration**: Add new columns if needed

### 1.3 Drop dead schema — ⬜ PENDING
- **Tables**: `agent_bot_versions` (unused)
- **Column**: `agent_bot_inboxes.version_id` (zero code references)
- **Migration**: Drop column + table

### 1.4 Seed `bot_action_templates` — ⬜ PENDING
- **Existing**: `db/schema.rb:394-406` (unused)
- **Plan**: Seed system rows (assign team, add label, set attribute, call webhook)

### 1.5 Create `BotFlow` model — ⬜ PENDING
- **Plan**: AR model mirroring `bot_flows` table

### 1.6 Create `bot_flows_controller.rb` — ⬜ PENDING
- **Plan**: CRUD + publish endpoints
- **Pattern**: Follow `agent_bots_controller.rb`

---

## Phase 2: Backend Engine — **10–15 days** (Not Started)

### 2.1 `BotFlowRuntimeService` — Step dispatcher
- **Effort**: 3–4d
- **Status**: Not started
- **Reuses**: `BotMessageSender`, `TemplateFacade` (unchanged)

### 2.2 Step matcher (decision step)
- **Effort**: 2–3d
- **Generalizes**: `INTERACTIVE_HANDLERS` + `FLOW_CONTROL_KEYWORDS` + `fuzzy_match_keyword`

### 2.3 Action dispatcher
- **Effort**: 1–2d
- **Reuses**: Existing Automation Rule action classes

### 2.4 Wait/delayed step
- **Effort**: 1d
- **Reuses**: `BotDelayedActionJob` (generalize pattern)

### 2.5 AI step (Captain LLM)
- **Effort**: 3–4d
- **Reuses**: `Captain::OpenAiMessageBuilderService`, `TasksAPI`

---

## Phase 3: Frontend Builder — **8–12 days** (Not Started)

### 3.1 Extend `agentBots/Index.vue`
- Type badge (Webhook / Flow)
- "Edit flow" action for flow-type bots

### 3.2 Nested route + `FlowBuilder.vue`
- Route: `settings/agent-bots/:agentBotId/flow-builder`
- Step list via `vuedraggable` (already installed)
- Step card components (message/decision/wait/action/ai)

### 3.3 Embed `ContentBlockEditor.vue` for message steps
- **Reuses**: 8 existing block editors (text, time_picker, list_picker, payment, form, quick_reply, media, button_group)

---

## Phase 4: Wire-up — **5–8 days** (Not Started)

### 4.1 Inbox association ("Edit flow" shortcut)
- Modify `BotConfiguration.vue`
- Extends existing `agentBots` Vuex module

### 4.2 Engine dispatch at trigger points
- Modify `incoming_message_service.rb#trigger_bot_if_enabled`
- Modify `messages_controller.rb#trigger_apple_messages_bot`

### 4.3 Test console (dry-run engine)
- Backend: Throwaway test conversation
- Frontend: "Test this flow" panel

### 4.4 Manual QA against sandbox AMB inbox
- Use existing `script/test_amb_bot.rb`

---

## Phase 5: Reference Flow + AI + Polish — **8–12 days** (Not Started)

### 5.1 Acoustic House reference flow
- Reproduce `AcousticHouseBotService` behavior via new system
- Parity proof against `docs/bot-studio/LEGACY_VS_STUDIO_COMPARISON.md`

### 5.2 AI step (Captain integration)
- Runtime LLM call during live conversation
- Instruction + tool allowlist + output mode

### 5.3 Version history / rollback UI
- `bot_flows` version listing

### 5.4 Read-only overview diagram
- Auto-generated from step list (secondary tab)

---

## Summary

| Phase | Estimate | Status |
|---|---|---|
| 1. Cleanup Migrations | 3–5d | ⏳ In Progress (1/6 done) |
| 2. Backend Engine | 10–15d | ⏳ Not Started |
| 3. Frontend Builder | 8–12d | ⏳ Not Started |
| 4. Wire-up | 5–8d | ⏳ Not Started |
| 5. Reference + AI + Polish | 8–12d | ⏳ Not Started |
| **Total** | **34–52d** | **~8–13 weeks (single FTE)** |

---

## Log

| Date | Action |
|---|---|
| (session start) | Created branch `feat/bot-flow-builder`, initialized progress file |
| (session 1) | Phase 1.1: Fixed `agent_bot.bot_type` enum |
