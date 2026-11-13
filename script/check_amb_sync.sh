#!/usr/bin/env bash
# Post-merge guard for upstream syncs: verifies the AMB invariants documented in
# docs/PHASE_7_SYNC_SUMMARY.md and docs/sync-v4.19.1/UPGRADE_PLAN.md still hold.
# Usage: script/check_amb_sync.sh   (exit 1 if any check fails)
cd "$(git rev-parse --show-toplevel)" || exit 1

FAIL=0
J=app/javascript/dashboard
REPLY_BOX=$J/components/widgets/conversation/ReplyBox.vue

has()  { grep -qE -- "$1" "$2" 2>/dev/null; }
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=1; }
must()    { if has "$2" "$3"; then pass "$1"; else fail "$1  [$2 missing in $3]"; fi; }
mustnot() { if has "$2" "$3"; then fail "$1  [$2 found in $3]"; else pass "$1"; fi; }

echo "ReplyBox.vue"
mustnot "no ResizableTextArea"                       'ResizableTextArea' $REPLY_BOX
must    "addIntoEditor uses updateEditorSelectionWith" 'updateEditorSelectionWith = content' $REPLY_BOX
mustnot "list_picker detection not gated on images"  '^[^/]*\(?(content|contentAttrs\??)\.?(attributes)?\.?sections *&& *\(?(content|contentAttrs)' $REPLY_BOX
must    "clearMessage appends signature by channel"  'effectiveChannelType' $REPLY_BOX
must    "TemplateSelector wired in"                  'TemplateSelector' $REPLY_BOX
mustnot "no AIAssistanceButton leftovers"            'AIAssistanceButton' $J/components/widgets/WootWriter/ReplyBottomPanel.vue
must    "AppleMessagesButton in bottom panel"        'AppleMessagesButton' $J/components/widgets/WootWriter/ReplyBottomPanel.vue

echo "Composer"
# TDZ: no watch() on listPickerData before its declaration (Vite 6 keeps TDZ strict)
C=$J/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue
decl=$(grep -n 'const listPickerData = ref' $C | head -1 | cut -d: -f1)
early=$(grep -nE 'watch\(.*listPickerData' $C | head -1 | cut -d: -f1)
if [ -n "$decl" ] && { [ -z "$early" ] || [ "$early" -gt "$decl" ]; }; then pass "listPickerData declared before any watch"; else fail "listPickerData watch before declaration (TDZ)"; fi

echo "Settings / navigation"
must "Settings.vue shows AMB configuration tab"      'isAnAppleMessagesForBusinessChannel' $J/routes/dashboard/settings/inbox/Settings.vue
must "ChannelName.vue i18nMap has AMB"               "Channel::AppleMessagesForBusiness" $J/routes/dashboard/settings/inbox/components/ChannelName.vue
must "Sidebar has Apple templates entry"             'apple_message_templates_list' $J/components-next/sidebar/Sidebar.vue
must "settings.routes registers apple templates"     'appleMessageTemplates' $J/routes/dashboard/settings/settings.routes.js
must "settings.routes registers upstream templates"  'templates\.routes' $J/routes/dashboard/settings/settings.routes.js
must "ChannelList offers AMB"                        'apple' $J/routes/dashboard/settings/inbox/ChannelList.vue
must "inbox.js knows AMB"                            'AppleMessagesForBusiness' $J/helper/inbox.js
must "Message.vue routes Apple bubbles"              'Apple' $J/components-next/message/Message.vue
must "editor.js exports WIDGET_BUILDER_EDITOR_MENU_OPTIONS" 'export const WIDGET_BUILDER_EDITOR_MENU_OPTIONS' $J/constants/editor.js

echo "Backend"
S=app/services/apple_messages_for_business/message_processor_service.rb
must "send_regular_message skips immediate SendReplyJob" 'skip_send_reply_job\] = true' $S
must "message_builder honours skip_send_reply_job"   'skip_send_reply_job' app/builders/messages/message_builder.rb
must "Channel::AppleMessagesForBusiness model present" 'class' app/models/channel/apple_messages_for_business.rb
must "AMB routes present"                            'apple_messages' config/routes.rb
must "inboxes_controller includes an existing health concern" 'Concerns::(Whatsapp|Inbox)HealthManagement' app/controllers/api/v1/accounts/inboxes_controller.rb

echo "Hygiene"
if git grep -nE '^(<<<<<<<|>>>>>>>) ' -- app lib config enterprise db spec ':!*.md' >/dev/null; then fail "conflict markers present"; else pass "no conflict markers"; fi
# imports of files that upstream deleted (v4.19.1): dangling imports break `vite build`
for dead in keyboardEventListenerMixins useLabelSuggestions LabelSuggestion SocialIcons; do
  if [ ! -e "$(git ls-files "*${dead}*" | head -1)" ] || [ -z "$(git ls-files "*${dead}*")" ]; then
    if git grep -nE "import .*${dead}" -- app/javascript >/dev/null; then fail "dangling import of ${dead}"; else pass "no dangling import of ${dead}"; fi
  fi
done

echo
if [ $FAIL -eq 0 ]; then echo "AMB sync guard: all checks passed"; else echo "AMB sync guard: FAILURES above"; exit 1; fi
