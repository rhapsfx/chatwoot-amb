# Upstream sync plan: v4.17.0 → v4.19.1

Fork base: `sync/v4.17.0` (HEAD `efc0fb218b`). Target: upstream tag `v4.19.1` (`c5c325a0bb`).
Goal: take all upstream changes without regressing AMB (Apple Messages for Business) or the fork's UI customisations.

Generated inputs live next to this file:

| File | Meaning |
|---|---|
| `upstream_changed_files.txt` / `upstream_diff_namestatus_*.txt` | 3,775 files changed upstream v4.17.0→v4.19.1 |
| `conflict_files.txt` | 77 files changed by BOTH upstream and the fork (vs v4.17.0) — the real merge surface |
| `amb_hot_files.txt` | 50 files with AMB references that upstream also touched — highest risk |
| `conflict_non_amb_files.txt` | 35 conflict files without AMB refs (infra, models, misc fork edits) |
| `upstream_deletions_renames.txt` | 119 upstream deletes/renames — check the fork for dangling references |
| `new_migrations.txt` | 28 new migrations (20260811 → 20261019) |
| `upstream_only_files.txt` | 3,698 files the fork never touched — safe bulk checkout (Phase 0+1) |

## Learnings applied (from repo docs and memory)

Sources: `docs/PHASE_7_SYNC_SUMMARY.md`, `docs/apple-messages/AMB_DEPENDENCY_MAP.md`, memory `project_amb_upgrade_pitfalls`, git history of `sync/v4.17.0`.

1. **Phase approach works**: 0+1 bulk-checkout untouched upstream files → 2 Gemfile/package.json + regenerate locks → 3 `db/schema.rb` → 4 i18n (`en.yml`/`en.json` only) → 5 Ruby conflict zone → 6 frontend conflict zone in small sub-phases (6a–6f) → 7 leftovers. Commit per phase.
2. **Upstream removes AMB code from shared files.** For files with many AMB refs (ReplyBox, ConfigurationPage, Settings, Message.vue) prefer *keep ours, then port the upstream change*, not *take upstream, then re-add AMB*. Re-adding loses things silently.
3. **Known regressions to re-check** (now automated in `script/check_amb_sync.sh`): ReplyBox dead `ResizableTextArea`; list_picker detection must key on `sections` only; `clearMessage` signature pattern; Composer TDZ `watch`; Settings AMB config tab; ChannelName `i18nMap`; Sidebar/route registration; `editor.js` exports; `skip_send_reply_job` flow in `send_regular_message`.
4. **Route collision**: upstream owns `templates` (settings route); the fork's page is `apple-message-templates` (`apple_message_templates_list`). Keep both in `settings.routes.js`; don't let upstream's `templates` overwrite the Apple one.
5. **Vite/pnpm pinning**: `pnpm.overrides` in `package.json` is ignored by pnpm v10 (per memory); there is no `.npmrc`/`pnpm-workspace.yaml` in the repo today. Verify the resolved Vite version after `pnpm install` rather than trusting `package.json`.
6. **Dependency-map doc** (`AMB_DEPENDENCY_MAP.md`): ReplyBox → TemplateSelector / ReplyBottomPanel → AppleMessagesButton; message bubbles (9) → `content_attributes`; i18n keys under `INBOX_MGMT.CHANNELS`. Use it to judge blast radius of any conflicting file.

## Pre-flight (before creating the sync branch)

The working tree on `sync/v4.17.0` is **dirty with deliberate local changes** that conflict with upstream's pins. Decide first, commit them on `sync/v4.17.0` (or stash) so the 4.19.1 merge starts clean:

- Ruby `3.4.4 → 3.4.12` (`.ruby-version`, `Gemfile`, `Gemfile.lock`, both Dockerfiles, `docker/Dockerfile`, CircleCI, devcontainer). **Upstream v4.19.1 still pins 3.4.4** → `Gemfile`/`Gemfile.lock`/`.ruby-version` will conflict; keep 3.4.12.
- Node `24.13.0 → 24.22.1` (`.nvmrc`, `docker/Dockerfile`). Upstream is already on 24.22.1 → no conflict, matches.
- `package.json` security bumps (axios, dompurify 3.4.17, js-cookie, markdown-it, vue 3.5.42, vite 6.4.5, plus new `pnpm.overrides`). `package.json` and `pnpm-lock.yaml` are in the conflict list — **re-apply these bumps on top of upstream's package.json, then regenerate the lock** (don't merge the lock by hand).
- `.claude/settings.json` — local only, keep out of the sync commits.

Then: `git switch -c sync/v4.19.1` from the clean `sync/v4.17.0`.

## Phases

### Phase 0+1 — bulk non-conflicting upstream files
Check out the 3,698 files in `upstream_only_files.txt` from `v4.19.1` (same method as `phase0_checkout.txt` in `docs/sync-v4.17.0/`). Apply deletions/renames from `upstream_deletions_renames.txt` **only** for files the fork has not modified (all of them are safe except as noted below).

Upstream renames/deletes that need care:
- **`whatsapp_health_management.rb` → `inbox_health_management.rb`** (module renamed `WhatsappHealthManagement` → `InboxHealthManagement`). The fork's `inboxes_controller.rb` (AMB-hot) includes the old module → update the `include` or `inboxes#show` will 500.
- **`shared/mixins/keyboardEventListenerMixins.js` deleted.** Fork copies still import it: `ReplyBox.vue` (conflict file) and `WootWriter/FullEditor.vue`. Upstream replaced it with the `useKeyboardEvents` composable. See ReplyBox notes in Phase 6.
- `LabelSuggestion.vue`, `useLabelSuggestions.js`, `SocialIcons.vue`, captain `assistants/overview/Index.vue`, WhatsApp campaign dialogs, `super_admin/push_diagnostics*`, administrate stylesheets/`secretField.js`/several super_admin views: confirm nothing in `apple`-related code imports them (grep found none today).
- Companies code moved from `enterprise/` into core (`app/…/companies*`, specs moved) — mirror, don't duplicate.

### Phase 2 — Gemfile / package.json / lockfiles
Take upstream manifests, re-apply the fork delta (Ruby 3.4.12, security bumps, any fork-only gems — see `git diff v4.17.0 HEAD -- Gemfile package.json`), then `bundle install` and `pnpm install` to regenerate locks. Check resolved `vite` version.

### Phase 3 — `db/schema.rb` + migrations
28 new migrations (conversation monitors, copilot runs/action items, AI assignee type, captain custom tool columns, call ring state, social-channel provider name, platform banner fields, …). Merge `schema.rb` keeping fork-only columns/tables (AMB tables/columns, "pgvector-free embeddings" decision from v4.17.0 Phase 3). Verify with `bin/rails db:migrate` on a copy of the production DB dump (see `docs/PROD_SYNC_GUIDE_V2.md`), not just an empty DB. Two data migrations (`backfill_*`, `backfill_encrypted_captain_custom_tool_credentials`) touch existing rows — read them before running on prod.

### Phase 4 — i18n
Only `en.yml` / `en.json`. `config/locales/en.yml` grew by ~467 lines upstream; keep fork keys (`SIDEBAR.APPLE_TEMPLATES`, `TEMPLATES.BUILDER.PARAMETERS`, AMB inbox strings in `inboxMgmt.json`/`conversation.json`/`automation.json`/`contact.json`/`settings.json`).

### Phase 5 — Ruby conflict zone (AMB-hot first)
Files, with what upstream changed that can interact with AMB:

| File | Upstream change | AMB risk |
|---|---|---|
| `app/builders/messages/message_builder.rb` | Forwarded-email attachments, `validate_forward`, boolean-cast `private`, subject in content_attributes | AMB relies on `skip_send_reply_job` and template attachment copy — keep that flow; `validate_forward` must stay a no-op for non-forward params |
| `app/models/message.rb` | New `content_attributes` store keys (`translation_*`, `source_language`), `not_forwarded` scope, `forwarded?` gating | Keep any AMB store keys/validators; `ContentAttributeValidator` is also a conflict file |
| `conversations/messages_controller.rb` | Translation provider refactor, `clear_source_id`, `prepend_mod_with` | Retry path (`clear_source_id`) must still skip clearing for AMB (non-api/widget) — verify it doesn't change retry semantics |
| `app/jobs/send_reply_job.rb` | Runs Captain agent-message translation first | Ensure AMB branch of the job still runs after it |
| `inboxes_controller.rb`, `_inbox.json.jbuilder` | Health concern rename, extra inbox attrs | Keep AMB attrs in jbuilder; fix `include` (above) |
| `models/{account,agent_bot,attachment,automation_rule,campaign}.rb`, `enterprise/…/concerns/attachment.rb` | Misc; `Attachment#download_url` now `url_for(file)` | AMB attachments/USDZ: re-test file delivery |
| `config/routes.rb` (+79) | New routes | Keep AMB + apple-message-templates + shared-images routes |

Non-AMB conflict files (`conversation.rb`, `user.rb`, `category.rb`, `platform_banner.rb`, `integrations/app.rb`, `rack_attack.rb`, `sidekiq.rb`, `apps.yml`, `redis_keys.rb`, captain/enterprise files, `.env.example`, `.gitignore`): take upstream, then re-add the fork delta shown by `git diff v4.17.0 HEAD -- <file>`. Note `rack_attack.rb` and `sidekiq.rb` broke in the 4.13 sync (misplaced throttle/`end`) → run `ruby -c` and boot Rails after.

### Phase 6 — frontend conflict zone (sub-phases, build after each)

6a. Message bubbles: `Message.vue` (+61 upstream), `MessageList.vue`, `bubbles/Base.vue`, `Text/Index.vue` (+99 upstream), `constants.js`. Keep the 9 Apple bubble components and their routing in `Message.vue`/`constants.js`; port upstream's forward/translation/voice-call additions in.

6b. Helpers/automation: `helper/inbox.js`, `composables/useInbox.js`, `automation/{constants,operators}.js` (AMB `group`/`intent` filters), `campaigns.routes.js`, `store/modules/campaigns.js`, `api/inbox/message.js`.

6c. Settings/inbox: `ChannelList.vue`, `ChannelItem.vue`, `inbox/Index.vue`, `inbox/Settings.vue`, `ConfigurationPage.vue` (keep ours; upstream's change is small: +6/−15), `CollaboratorsPage.vue`.

6d. Layout/navigation (the "custom UI layout" surface): `Sidebar.vue` (+27 upstream; fork adds the Apple Templates entry), `_woot.scss` (upstream −80 lines; fork adds the AMB modal blue-border rules — re-add after taking upstream), `ConversationInfo.vue` (fork adds Apple capabilities panel and null-object `{value}` computed shape; upstream +17/−3), `vueapp.html.erb`.

6e. **ReplyBox.vue** (upstream +140/−125 — the riskiest file). Upstream moved to `useKeyboardEvents` (dropping `keyboardEventListenerMixins`), added `isComposing` IME guard, voice-call default-note mode, forwarded/quoted-email state, `getReplyVariables`, `isAIOwnedPendingConversation`. Strategy: keep the fork file, port these hunks one by one; the fork's `TemplateSelector` keydown fix (`d0dfefeb98`) must be re-validated against the new keyboard handling — `/` selection must not leak into ProseMirror and Enter must not send while the selector is open. Then run the guard script.
   `ReplyBottomPanel.vue` (upstream +12/−25): take upstream, confirm `AppleMessagesButton` and USDZ support survive.

6f. `FullEditor.vue` and any other remaining importer of the deleted mixin → migrate to `useKeyboardEvents`.

### Phase 7 — leftovers + dangling-import sweep
`pnpm exec vite build` (catches dead imports like the 4.13 `AIAssistanceButton` and missing exports), `pnpm eslint`, `bundle exec rubocop`.

## Verification gate (run after every phase from 5 onward)

```bash
./script/check_amb_sync.sh                     # AMB invariants (passes on current HEAD)
pnpm exec vite build && pnpm test              # frontend
bundle exec rspec spec/services/apple_messages_for_business spec/models/channel spec/controllers/api/v1/accounts/conversations
bundle exec rails runner script/test_amb_bot.rb -- INBOX_ID CONVERSATION_ID   # all bot payloads
```

Manual (dev server `./script/dev-server.sh start`):
- `/` in an AMB conversation → list_picker template sends the rich Apple payload (not plain text); USDZ-only template arrives on the device.
- Settings → Apple Templates visible; Settings → Inboxes → AMB inbox shows "Apple Messages for Business" and the Configuration tab (OAuth, Apple Pay, iMessage app).
- Conversation sidebar shows Apple capabilities; AMB auth/payment modals keep the blue border (light + dark).
- Sidebar, conversation list and reply box layout match the pre-merge screenshots (capture them on `sync/v4.17.0` first).
- Non-AMB regression: web widget and email reply still send (upstream touched `message_builder`/`send_reply_job`).

## Rollback / deploy
Production is the Synology NAS (`docker-compose.nas.yml`, see memory `project_production_deployment`). Take a DB dump before running the 28 migrations; keep the `sync/v4.17.0` image tag to roll back (schema changes are additive, but the data backfills are not reversible).

## Open questions
- No document in the repo defines "custom UI layout" explicitly. This plan treats it as the fork's edits to `Sidebar.vue`, `_woot.scss`, `ConversationInfo.vue`, `bubbles/Base.vue`, `MessageList.vue`, `Text/Index.vue` and the inbox settings pages. If you have other layout changes (e.g. in the conversation list or app shell), name them and I'll add them to the guard script.

## Execution log and learnings (branch `sync/v4.19.1`)

Phases 0+1 through 6 are committed; every commit passes `script/check_amb_sync.sh`. Verification run on the merged tree: Rails migrations on a clone of the dev DB (all 28 apply), `zeitwerk:check`, production `vite build`, ESLint, ~3,900 backend specs, and `script/test_amb_bot.rb --dry-run` (31/31 triggers).

### Method that worked
- **Three-way merge per file** (`git merge-file` with base = upstream previous tag, ours = pre-sync commit, theirs = new tag), then resolve hunks by hand. For the i18n JSON files a **key-level merge** (parse, merge per leaf key, emit in upstream key order) turned ~45 line-conflicts into 1 real one and cut the diff against upstream from ~5,000 lines to the fork's actual additions.
- **Rebuild from upstream and re-apply the fork delta** when upstream restructured the file (`Base.vue`, `apps.yml`, `access_token_auth_helper.rb`); patch conflict markers only for small hunks.
- **Baseline against pristine upstream**: a git worktree of the upstream tag, same Ruby/gems/DB, run the same specs. It proved the 23 wide-suite failures are environmental (identical on upstream) and isolated 2 real fork regressions.
- The `db:migrate` run triggers the annotation rake task and rewrites ~20 model files; revert them (`git checkout -- app enterprise`).

### Stale fork drift found and removed (not AMB features)
Carried over from the fork's original import and never reconciled with upstream: `belongs_to :conversation, touch: true` and `reorder('id desc')` in `message.rb`; webhook payloads using rendered `outgoing_content` instead of raw `webhook_content`; a corrupted `"_\#{message_text}_"` in the Slack service (literal text in Slack activity messages); token-prefix debug logging in `access_token_auth_helper.rb`; stale English wording for 14 i18n keys. Check `git diff v4.X efc... -- <file>` for such "fork modified an existing non-AMB line" cases on every sync.

### Decisions worth knowing
- **messages_controller#create**: the AMB `create_params` allowlist is now used only on the Apple branch; the regular branch passes raw `params` like upstream. The allowlist silently dropped `cc_emails`, `bcc_emails`, `to_emails`, `subject`, `forwarded_attachment_ids`, `template_params`, `email_html_content`.
- **Bot API contract kept**: `X-Api-Access-Token` header and `?api_access_token=` still authenticate (documented in `docs/api/BOT_TEMPLATES_API.md`); implemented inside upstream's `legacy_access_token`.
- **perplexity integration** kept, without the `label_suggestion` option (feature removed upstream).
- **Quoted-reply toggle** (`toggleQuotedReply`, `setQuotedReplyFlagForInbox`) dropped in favour of upstream's remove/restore flow.
- **Left as-is** (pre-existing, unused): `posthog-js` and `vue-virtual-scroller` in `package.json`, `toggleRichContentEditor`/`showRichContentEditor` in ReplyBox, 🔥 `console.log` debugging in `api/inbox/message.js` and `replaceText`.
- `spec/models/message_spec.rb:152` expects upstream's `push_event_data` keys and fails on the fork's `apple_msp_payload`; left unedited to avoid re-conflicting an upstream spec every sync.

### Environment gotchas
- Ruby 3.4.12 must be built against `openssl@3` on this Mac (`RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"`); Homebrew's default OpenSSL 4 breaks the locked `openssl 3.2.0` gem.
- Local Postgres has no `pgvector`; the fork's schema omits the `vector` extension (upstream's `schema.rb` can't load locally).
- Node here is v26; the repo wants 24.x. 56 vitest tests fail only from that (storage/timezone/`Intl` in jsdom); none touch fork code.
- `script/*` is gitignored; new scripts need `git add -f`.
- The rspec wide-run failures (report builder, audit logs, SLA, agent builder) depend on test ordering/shared DB and also fail on pristine upstream; they pass in isolation.
