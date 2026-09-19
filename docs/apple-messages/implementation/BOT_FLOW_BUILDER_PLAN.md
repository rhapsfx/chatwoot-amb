# AMB Bot Flow Builder — Full Plan

## Context

Chatwoot currently ships exactly one AMB (Apple Messages for Business) conversational bot, `AcousticHouseBotService` (`app/services/apple_messages_for_business/acoustic_house_bot_service.rb`, ~2,900 lines) — a monolithic, hard-coded Ruby state machine (string states like `AHA1`, `AHB2`, keyword/interactive dispatch tables, retry counters, idle timeouts, delayed jobs) that showcases every AMB template type but can only be changed by writing Ruby. There is no way for anyone to author, branch, reorder, duplicate, or attach a *different* bot flow to an inbox through the UI.

Three prior attempts at a builder exist in this repo's history, all unmerged:
1. **n8n visual workflow** — abandoned as unmaintainable (80+ nodes, no code reuse, an HTTP round-trip per state transition).
2. **Dialogflow CX** — got to a prototype export, never carried further.
3. **"Bot Studio"** (branch `amb-beta-bot-studio`) — an in-house free-form node-canvas editor (`BotStudioCanvas.vue`, `FlowCompilerService`, etc.). Its own retrospective (`docs/bot-studio/LEGACY_VS_STUDIO_COMPREHENSIVE_COMPARISON.md`) shows why it stalled: the visual graph only ever expressed ~11 simple nodes against the real bot's 30+ states with deep retry/timeout/idle-reset/error-recovery logic — an estimated 6-8 more weeks to reach parity, never merged. A `bot_flows` / `bot_action_templates` schema from that attempt is still sitting unused in `db/schema.rb` today.

The goal now is a **robust alternative**, informed by that failure: don't try to hand-draw arbitrary control flow on a canvas. Instead, (a) reuse everything Chatwoot already has for authoring AMB message content, (b) model flow structure as a constrained, linear step list with data-driven branching, and (c) push the hard runtime concerns (retry, timeout, idle-reset, error fallback) into generic per-step configuration in the engine, not bespoke code per bot — so authors get that robustness for free instead of the builder needing to reinvent it visually.

Decisions confirmed with the user:
- **UI paradigm:** linear, reorderable step-list (not a node canvas) — matches existing in-house patterns (`MacroNodes.vue`, `ContentBlockList.vue`) and avoids Bot Studio's failure mode.
- **Relation to the legacy bot:** coexist. `AcousticHouseBotService` keeps running unchanged. The new engine must additionally ship a reference flow that **exactly remimics Acoustic House**, built entirely through the new system, as its parity proof and starter template.
- **AI block:** a runtime step type — an LLM call, during a live conversation, that composes a reply and/or picks the next branch.

## Architecture Decisions

### 1. Reuse `agent_bots` as the flow's identity; repurpose `bot_flows` as its version history

- Fix the long-standing enum drift in `app/models/agent_bot.rb:41` (`enum bot_type: { webhook: 0 }` — the DB comment already documents value `1` but Rails never declared it). Rename it to `{ webhook: 0, flow: 1 }` (small migration; no existing rows use value 1, so this is safe).
- An `AgentBot` with `bot_type: flow` is a *flow-backed bot*: its behavior comes from a published `BotFlow` version instead of an external webhook URL. It attaches to inboxes exactly the way `AgentBot` already does today via `agent_bot_inboxes` — no new association layer needed for inbox coordination.
- Repurpose the dead `bot_flows` table (`db/schema.rb:408-426`, `agent_bot_id`, `flow_data jsonb`, `version`, `version_tag`, `parent_flow_id`, `is_published`, `published_at`, `changelog`) as **version snapshots** of a flow: each row is one immutable(-ish) version, `flow_data` holds the full step graph (schema below). Add a partial unique index `(agent_bot_id) WHERE is_published` so only one version is ever live per bot. Editing always targets the latest non-published version; hitting "Edit" after publish clones the published version into a new draft row (mirrors how `MessageTemplate` versioning-by-copy already works conceptually).
- Drop the redundant, fully-unused `agent_bot_versions` table and `agent_bot_inboxes.version_id` column (`db/schema.rb:131-146`, confirmed zero code references) — it was a second, never-finished attempt at the same versioning idea `bot_flows` already covers; keeping both would just recreate the dead-schema confusion this plan is meant to resolve.
- Reinterpret `bot_action_templates` (`db/schema.rb:394-406`: `account_id`, `name`, `template_type`, `parameters jsonb`, `execution_order`) as the **catalog of non-message action step kinds** available in the builder (assign team, add label, set conversation attribute, call webhook, …) — system-seeded rows (`account_id: nil`) plus optional account-defined custom actions later. This is the same "palette of typed things a step can do" role `TemplateContentBlock::BLOCK_TYPES` plays for message content, just for actions.

### 2. `flow_data` step schema (inside `bot_flows.flow_data`)

An ordered array of steps, each with a stable UUID `id` (not array index, so branch targets survive reordering) and a `step_type`:

- **`message`** — `message_template_id` referencing an existing `MessageTemplate` row. This is the key reuse: every AMB format already implemented (`list_picker`, `time_picker`, `form`, `rich_link`, `apple_pay`, `quick_reply`, `media`, `button_group`, `auth`/`oauth`, `imessage_app`) is authored through the existing `TemplateContentBlock`/`TemplateFacade` machinery — the flow builder does not need a single new message-content editor.
- **`decision`** — ordered `rules: [{match: {type: keyword|interactive_id|form_field, value, fuzzy: bool}, next_step_id}]` + `default_next_step_id`. Generalizes `AcousticHouseBotService`'s `INTERACTIVE_HANDLERS`/keyword tables/`fuzzy_match_keyword` into data instead of Ruby `case` branches.
- **`action`** — `action_type` (from the `bot_action_templates` catalog) + `parameters`.
- **`wait`** — `delay_seconds`, `next_step_id`. Generalizes `schedule_delayed_action`/`BotDelayedActionJob` into a data-driven continuation instead of named-method re-invocation.
- **`ai`** — `instruction` (prompt), optional `tool_allowlist`, `output_mode: message|decision`, `fallback_next_step_id`.

Every step also carries the generic robustness primitives that Bot Studio lacked: `max_retries` + `retry_message` + `on_max_retries_next_step_id`, `step_timeout_seconds` + `on_timeout_next_step_id`, `on_error_next_step_id`. Flow-level: `idle_timeout_minutes` + `idle_next_step_id`, `global_keywords` (restart/menu-style jumps reachable from any step, generalizing `FLOW_CONTROL_KEYWORDS`).

### 3. Runtime engine

New `AppleMessagesForBusiness::BotFlowRuntimeService`, triggered from the exact same entry points `AcousticHouseBotService` uses today (`incoming_message_service.rb#trigger_bot_if_enabled`, `messages_controller.rb#trigger_apple_messages_bot`), dispatching to the flow engine when `conversation.inbox.agent_bot&.flow?`, otherwise falling through to existing hardcoded behavior unchanged. It:
- Reuses `BotStateManager`'s pattern (state in `conversation.custom_attributes`), generalized to `current_step_id` + a free-form `flow_vars` hash instead of named ad hoc keys.
- Reuses `BotMessageSender`, `TemplateFacade`, `CaseTransformer`, `ImageFetchService` **unchanged** to actually send messages — no new sending code.
- Implements one data-driven matcher for inbound text/interactive taps against the current step's `decision` rules (reusing the existing fuzzy-match logic, generalized).
- Implements the action-step dispatcher (reusing existing Automation Rule action classes where they already cover the same action, e.g. assign team / add label, instead of duplicating them).
- Implements the AI-step executor by calling into Captain's existing LLM/task plumbing (the same backend behind `useCaptain`/`TasksAPI`), passing the step's instruction and tool allowlist Scenario-style — no new LLM client code.

### 4. Frontend

Lives inside the existing **Settings → Agent Bots** area (see navigation, §5), not a new top-level settings section:
- **List view** — the existing `agentBots/Index.vue`, extended with a type badge and duplicate/reorder-priority actions, same conventions as `apple-message-templates/Index.vue`.
- **`FlowBuilder.vue`** (new) — step list via `vuedraggable` (already an installed dependency), same drag/reorder/add/remove conventions as `MacroNodes.vue` and `ContentBlockList.vue`. Each step is a collapsed/expandable card.
  - `message` steps embed the **existing** `ContentBlockEditor.vue` and its per-type editors directly — zero new authoring UI for message content.
  - `decision` steps: rule rows (match-type dropdown, value, target-step picker) + default target, modeled on `AutomationActions.vue`'s add/remove-row pattern.
  - `action` steps: action-type dropdown from the `bot_action_templates` catalog + dynamic parameter fields, same pattern.
  - `wait` steps: a duration input.
  - `ai` steps: instruction textarea + tool checklist + output-mode toggle, modeled on Captain's Scenario instruction UI.
  - Retry/timeout/error-fallback controls live in a collapsible "Advanced" section per card — available when needed, hidden by default to keep the primary view simple.
  - A **read-only, auto-generated overview diagram** (derived from the step list, not hand-edited) as a secondary tab — gives the "visual" bird's-eye view without reintroducing canvas-editing complexity.
  - A **"Test this flow" tab** (see §6) for behavioral preview of the draft.
- **Version history** (new, small) — list of a flow's `bot_flows` versions with publish/rollback actions.
- **Inbox association** — extend the existing `BotConfiguration.vue` (`settings/inbox/components/BotConfiguration.vue`) + `agentBots` Vuex module (`setAgentBotInbox`/`disconnectBot`) rather than building a new pattern; flow-backed bots simply appear alongside webhook bots in that same select (see §5 for the reverse "edit flow from the inbox page" shortcut).
- **Branding** — apply `useBranding`/`replaceInstallationName` to all new builder copy (a gap the current `TemplateBuilder.vue` also has and should pick up).

### 5. Navigation — where the builder lives in the Chatwoot UI

Confirmed via the sidebar/routes: there is already a top-level entry, **Settings → Agent Bots** (`Sidebar.vue:871-874`, label `SIDEBAR.AGENT_BOTS`, route `agent_bots` → `settings/agent-bots`, gated by `FEATURE_FLAGS.AGENT_BOTS`), backed by `agentBots/Index.vue` (a flat list) and a simple `AgentBotModal.vue` (name/description/outgoing_url fields for webhook bots). This is the natural, existing home for the flow builder — no new top-level sidebar item is needed:

- `agentBots/Index.vue` gains a type badge (Webhook / Flow) per row and, for `flow`-type bots, an "Edit flow" action instead of opening `AgentBotModal.vue`.
- New nested route `settings/agent-bots/:agentBotId/flow-builder` (added to `agentBot.routes.js`, same permission/feature-flag gating) renders the full-page `FlowBuilder.vue` — a flow's step list doesn't fit a modal, so it gets its own page, consistent with how `TemplateBuilder.vue` is a full page off the AMB Templates list rather than a modal.
- "Create bot" gains a type choice up front (Webhook vs Flow); choosing Flow creates the `AgentBot(bot_type: :flow)` + an initial empty draft `bot_flows` version, then navigates straight into `FlowBuilder.vue`.
- A secondary, contextual entry point: on the inbox's existing bot-selection UI (`settings/inbox/components/BotConfiguration.vue`), when the inbox's selected bot is flow-type, show an inline "Edit flow" link next to the selector that jumps directly into `FlowBuilder.vue` for that bot — so an admin configuring an inbox never has to leave and hunt through the Agent Bots list to adjust the flow behind it.

### 6. Preview / test console

Two levels, both reusing existing pieces rather than inventing new rendering:

- **Per-step content preview** — reuse the existing `TemplatePreview.vue` (already built for `TemplateBuilder.vue`) unchanged to render a live mock of whichever step's message content is currently selected/expanded in `FlowBuilder.vue`. Zero new rendering code for this part.
- **Whole-flow test console** — a "Test this flow" panel that lets the author click through the *draft* (unpublished) flow exactly as an end user would: tap list-picker options, type keywords, see the bot's replies rendered as chat bubbles, all without touching a real Apple device or sending a real MSP request. Critically, this runs against the **same `BotFlowRuntimeService`** used in production, executed against a throwaway/test `Conversation` (or an in-memory equivalent) instead of a live one — so the preview can never drift from actual runtime behavior, which is a real risk with a hand-simulated preview. This directly revives the intent behind the abandoned Bot Studio branch's `BotTestConsole.vue`, this time backed by the shared engine instead of bespoke simulation logic. Available from `FlowBuilder.vue` at any point while editing, before publishing.
- The read-only auto-generated overview diagram (already in §4) is a *structural* preview (what steps exist and how they connect); the test console is a *behavioral* preview (what actually happens when you run it). Both are useful and cheap given the reuse above.

### 7. Required reference flow

Ship a system-provided "Acoustic House (reference)" flow, authored entirely through the new builder, reproducing `AcousticHouseBotService`'s behavior — including its retry/timeout/idle-reset/fuzzy-match/delayed-action mechanics via the generic per-step primitives above. This is the parity proof: walk `docs/bot-studio/LEGACY_VS_STUDIO_COMPREHENSIVE_COMPARISON.md`'s gap list and confirm each is now closed. `AcousticHouseBotService` itself is left untouched and keeps running; the reference flow is a duplicatable starter template, not a cutover.

## Phasing

1. **Cleanup migrations** — `bot_type` enum fix, drop `agent_bot_versions` + `agent_bot_inboxes.version_id`, add published-uniqueness index on `bot_flows`, reinterpret `bot_action_templates` as the action catalog (seed system rows).
2. **Backend engine** — `flow_data` schema, `BotFlowRuntimeService`, step matcher/executor, minimal CRUD/publish API. Feature-flagged (reuse the existing account feature-flag mechanism that already gates Captain), not yet wired to any real inbox.
3. **Frontend builder** — extend `agentBots/Index.vue` + `agentBot.routes.js` with the type badge and `flow-builder` nested route; `FlowBuilder.vue` with message/decision/wait/action step types (AI step deferred to phase 5), reusing `ContentBlockEditor.vue` for message steps; the per-step `TemplatePreview.vue` reuse.
4. **Wire-up** — inbox association via `BotConfiguration.vue` (including the "Edit flow" shortcut), engine dispatch at the existing trigger points, the server-side "Test this flow" console (dry-run `BotFlowRuntimeService` against a throwaway conversation), then manual QA against a real sandbox AMB inbox using the project's existing `script/test_amb_bot.rb` tooling.
5. **Reference flow + AI step + polish** — author and validate the Acoustic House reference flow against the comparison doc's gap list; add the runtime AI step (Captain integration); add version history/rollback UI and the read-only overview diagram.

## Verification

- Rails specs: `BotFlowRuntimeService` state transitions, step matcher (keyword/fuzzy/interactive), action executor, AI step executor (mocked LLM), migrations (enum, dropped columns/tables).
- Frontend: component tests for step CRUD/reorder/duplicate in `FlowBuilder.vue`.
- End-to-end: build a flow covering every step type, publish it, attach it to a sandbox AMB inbox, and converse through it using `rails runner script/test_amb_bot.rb -- INBOX_ID CONVERSATION_ID` (per this project's existing AMB bot test tooling) to confirm real message delivery for each template type.
- Explicit parity pass: re-check every gap flagged in `docs/bot-studio/LEGACY_VS_STUDIO_COMPREHENSIVE_COMPARISON.md` against the new Acoustic House reference flow.
