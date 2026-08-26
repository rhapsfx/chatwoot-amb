<script>
import { defineAsyncComponent, useTemplateRef } from 'vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useTrack } from 'dashboard/composables';
import keyboardEventListenerMixins from 'shared/mixins/keyboardEventListenerMixins';

import TemplateSelector from './TemplateSelector.vue';
import ReplyToMessage from './ReplyToMessage.vue';
import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import ReplyTopPanel from 'dashboard/components/widgets/WootWriter/ReplyTopPanel.vue';
import ReplyEmailHead from './ReplyEmailHead.vue';
import ReplyBottomPanel from 'dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import ArticleSearchPopover from 'dashboard/routes/dashboard/helpcenter/components/ArticleSearch/SearchPopover.vue';
import CopilotEditorSection from './CopilotEditorSection.vue';
import MessageSignatureMissingAlert from './MessageSignatureMissingAlert.vue';
import ReplyBoxBanner from './ReplyBoxBanner.vue';
import QuotedEmailPreview from './QuotedEmailPreview.vue';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { CMD_AI_ASSIST } from 'dashboard/helper/commandbar/events';
import {
  getMessageVariables,
  getUndefinedVariablesInMessage,
  replaceVariablesInMessage,
} from '@chatwoot/utils';
import WhatsappTemplates from './WhatsappTemplates/Modal.vue';
import ContentTemplates from './ContentTemplates/ContentTemplatesModal.vue';
import { MESSAGE_MAX_LENGTH } from 'shared/helpers/MessageTypeHelper';
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';
import { trimContent, debounce, getRecipients } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import {
  extractQuotedEmailText,
  buildQuotedEmailHeader,
  truncatePreviewText,
  appendQuotedTextToMessage,
} from 'dashboard/helper/quotedEmailHelper';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import fileUploadMixin from 'dashboard/mixins/fileUploadMixin';
import {
  appendSignature,
  removeSignature,
  replaceSignature,
  extractTextFromMarkdown,
  getEffectiveChannelType,
  getAgentVariables,
  getContactVariables,
} from 'dashboard/helper/editorHelper';
import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useMacroExecution } from 'dashboard/composables/useMacroExecution';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { isFileTypeAllowedForChannel } from 'shared/helpers/FileHelper';
import AppleRichLinkPreview from './AppleRichLinkPreview.vue';
import {
  URL_REGEX,
  detectURLsInText,
  processMessageForAppleMessages,
} from 'dashboard/helper/appleMessagesRichLink';

import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { LocalStorage } from 'shared/helpers/localStorage';
import { emitter } from 'shared/helpers/mitt';
const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

export default {
  components: {
    AppleRichLinkPreview,
    ArticleSearchPopover,
    AttachmentPreview,
    AudioRecorder,
    TemplateSelector,
    ReplyBoxBanner,
    EmojiIconPicker,
    MessageSignatureMissingAlert,
    ReplyBottomPanel,
    ReplyEmailHead,
    ReplyToMessage,
    ReplyTopPanel,
    ContentTemplates,
    WhatsappTemplates,
    WootMessageEditor,
    QuotedEmailPreview,
    CopilotEditorSection,
    CopilotReplyBottomPanel,
    ConversationResolveAttributesModal,
  },
  mixins: [inboxMixin, fileUploadMixin, keyboardEventListenerMixins],
  props: {
    popOutReplyBox: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['toggleEditorSize', 'update:popOutReplyBox'],
  setup() {
    const {
      uiSettings,
      updateUISettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
    } = useUISettings();

    const replyEditor = useTemplateRef('replyEditor');
    const messageEditor = useTemplateRef('messageEditor');
    const copilot = useCopilotReply();
    const macroExecution = useMacroExecution();
    const shortcutKey = useKbd(['$mod', '+', 'enter']);

    return {
      uiSettings,
      updateUISettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
      replyEditor,
      messageEditor,
      copilot,
      shortcutKey,
      macroExecution,
    };
  },
  data() {
    return {
      message: '',
      inReplyTo: {},
      isFocused: false,
      showEmojiPicker: false,
      attachedFiles: [],
      isRecordingAudio: false,
      recordingAudioState: '',
      recordingAudioDurationText: '',
      isUploading: false,
      replyType: REPLY_EDITOR_MODES.REPLY,
      mentionSearchKey: '',
      hasSlashCommand: false,
      draftConversationId: null,
      draftReplyMode: null,
      bccEmails: '',
      ccEmails: '',
      toEmails: '',
      doAutoSaveDraft: () => {},
      showWhatsAppTemplatesModal: false,
      showContentTemplatesModal: false,
      updateEditorSelectionWith: '',
      undefinedVariableMessage: '',
      showMentions: false,
      showUserMentions: false,
      showCannedMenu: false,
      showVariablesMenu: false,
      showMacrosMenu: false,
      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
      // Rich Link preview
      richLinkPreviewUrl: '',
      showRichLinkPreview: false,
      richLinkDetectionTimeout: null,
      richLinkCachedData: null,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      messageSignature: 'getMessageSignature',
      currentUser: 'getCurrentUser',
      lastEmail: 'getLastEmailInSelectedChat',
      globalConfig: 'globalConfig/get',
      isMetaMessageSendingDisabled: 'globalConfig/isMetaMessageSendingDisabled',
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    isMacrosEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.MACROS
      );
    },
    currentContact() {
      const senderId = this.currentChat?.meta?.sender?.id;
      if (!senderId) return {};
      return this.$store.getters['contacts/getContact'](senderId);
    },
    shouldShowReplyToMessage() {
      return (
        this.inReplyTo?.id &&
        !this.isPrivate &&
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO) &&
        !this.is360DialogWhatsAppChannel &&
        !this.copilot.isActive.value
      );
    },
    showRichContentEditor() {
      if (this.isOnPrivateNote || this.isRichEditorEnabled) {
        return true;
      }

      if (this.isAPIInbox) {
        const {
          display_rich_content_editor: displayRichContentEditor = false,
        } = this.uiSettings;
        return displayRichContentEditor;
      }

      return false;
    },
    showWhatsappTemplates() {
      // We support templates for API channels if someone updates templates manually via API
      // That's why we don't explicitly check for channel type here
      const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](
        this.inboxId
      );
      return !!(templates && templates.length) && !this.isPrivate;
    },
    showContentTemplates() {
      // Only show for Twilio WhatsApp, not for Apple Messages
      // Apple Messages uses the / command (TemplateSelector)
      return this.isATwilioWhatsAppChannel && !this.isPrivate;
    },
    isWithinMessagingWindow() {
      return !!(
        this.currentChat?.can_reply ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox
      );
    },
    canSendPublicReply() {
      return (
        this.isWithinMessagingWindow &&
        !this.isBotOwnedPendingConversation &&
        !this.isInstagramReplyRestricted
      );
    },
    isInstagramReplyRestricted() {
      return this.isMetaMessageSendingDisabled && this.isAnInstagramChannel;
    },
    isPrivate() {
      return (
        !this.canSendPublicReply || this.replyType === REPLY_EDITOR_MODES.NOTE
      );
    },
    isOnPrivateNote() {
      if (this.isInstagramReplyRestricted) {
        return true;
      }

      return this.isBotOwnedPendingConversation
        ? this.isPrivate
        : this.replyType === REPLY_EDITOR_MODES.NOTE;
    },
    effectiveReplyMode() {
      return this.isOnPrivateNote
        ? REPLY_EDITOR_MODES.NOTE
        : REPLY_EDITOR_MODES.REPLY;
    },
    hasMeaningfulEditorContent() {
      const body = this.message || '';
      // Only strip the signature when it's actually being auto-appended.
      // If the toggle is off, the agent's text might happen to match their
      // saved signature and we'd incorrectly treat it as empty.
      const shouldStripSignature =
        !this.isPrivate && this.sendWithSignature && !!this.messageSignature;
      if (!shouldStripSignature) return !!body.trim();
      const stripped = removeSignature(
        body,
        this.messageSignature,
        getEffectiveChannelType(this.channelType, this.inbox?.medium || '')
      );
      return !!stripped.trim();
    },
    isBotOwnedPendingConversation() {
      return (
        this.currentChat?.status === wootConstants.STATUS_TYPE.PENDING &&
        this.currentChat?.meta?.assignee_type === 'AgentBot'
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    isAppleMessagesConversation() {
      return this.inbox?.channel_type === 'Channel::AppleMessagesForBusiness';
    },
    messagePlaceHolder() {
      if (this.isEditorDisabled) {
        if (this.isAWhatsAppChannel) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_WHATSAPP');
        }
        if (this.isAPIInbox) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_API');
        }
        return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED');
      }
      return this.isPrivate
        ? this.$t('CONVERSATION.FOOTER.PRIVATE_MSG_INPUT')
        : this.$t('CONVERSATION.FOOTER.MSG_INPUT');
    },
    isMessageLengthReachingThreshold() {
      return this.message.length > this.maxLength - 50;
    },
    charactersRemaining() {
      return this.maxLength - this.message.length;
    },
    isReplyButtonDisabled() {
      if (this.isEditorDisabled) return true;
      if (this.isATwitterInbox) return true;
      if (this.hasAttachments || this.hasRecordedAudio) return false;

      return (
        this.isMessageEmpty ||
        this.message.length === 0 ||
        this.message.length > this.maxLength
      );
    },
    sender() {
      return {
        name: this.currentUser.name,
        thumbnail: this.currentUser.avatar_url,
      };
    },
    conversationType() {
      const { additional_attributes: additionalAttributes } = this.currentChat;
      const type = additionalAttributes ? additionalAttributes.type : '';
      return type || '';
    },
    maxLength() {
      if (this.isPrivate) {
        return MESSAGE_MAX_LENGTH.GENERAL;
      }
      if (this.isAFacebookInbox) {
        return MESSAGE_MAX_LENGTH.FACEBOOK;
      }
      if (this.isAnInstagramChannel) {
        return MESSAGE_MAX_LENGTH.INSTAGRAM;
      }
      if (this.isATelegramChannel) {
        return MESSAGE_MAX_LENGTH.TELEGRAM;
      }
      if (this.isATiktokChannel) {
        return MESSAGE_MAX_LENGTH.TIKTOK;
      }
      if (this.isATwilioWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_WHATSAPP;
      }
      if (this.isAWhatsAppCloudChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      if (this.isASmsInbox) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAnEmailChannel) {
        return MESSAGE_MAX_LENGTH.EMAIL;
      }
      if (this.isATwilioSMSChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      return MESSAGE_MAX_LENGTH.GENERAL;
    },
    showFileUpload() {
      const { image_send: imageSend } =
        this.currentChat?.additional_attributes?.tiktok_capabilities ?? {};
      const tiktokAttachmentSupported = imageSend ?? true;

      return (
        this.isAWebWidgetInbox ||
        this.isAFacebookInbox ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox ||
        this.isAnEmailChannel ||
        this.isASmsInbox ||
        this.isATelegramChannel ||
        this.isALineChannel ||
        this.isAnInstagramChannel ||
        (this.isATiktokChannel && tiktokAttachmentSupported) ||
        this.isAnAppleMessagesForBusinessChannel
      );
    },
    replyButtonLabel() {
      let sendMessageText = this.$t('CONVERSATION.REPLYBOX.SEND');
      if (this.isPrivate) {
        sendMessageText = this.$t('CONVERSATION.REPLYBOX.CREATE');
      }
      const keyLabel = this.isEditorHotKeyEnabled('cmd_enter')
        ? `(${this.shortcutKey})`
        : '(↵)';
      return `${sendMessageText} ${keyLabel}`;
    },
    replyBoxClass() {
      return {
        'is-private': this.isPrivate,
        'is-focused': this.isFocused || this.hasAttachments,
      };
    },
    hasAttachments() {
      return this.attachedFiles.length;
    },
    isRichEditorEnabled() {
      return this.isAWebWidgetInbox || this.isAnEmailChannel;
    },
    showAudioRecorder() {
      return !this.isOnPrivateNote && this.showFileUpload;
    },
    showAudioRecorderEditor() {
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },
    isMessageEmpty() {
      if (!this.message) {
        return true;
      }
      return !this.message.trim().replace(/\n/g, '').length;
    },
    showReplyHead() {
      return !this.isOnPrivateNote && this.isAnEmailChannel;
    },
    enableMultipleFileUpload() {
      return (
        this.isAnEmailChannel ||
        this.isAWebWidgetInbox ||
        this.isAPIInbox ||
        this.isAWhatsAppChannel ||
        this.isATelegramChannel
      );
    },
    isSignatureEnabledForInbox() {
      return !this.isPrivate && this.sendWithSignature;
    },
    isSignatureAvailable() {
      return !!this.messageSignature;
    },
    sendWithSignature() {
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    editorMessageKey() {
      const { editor_message_key: isEnabled } = this.uiSettings;
      return isEnabled;
    },
    commandPlusEnterToSendEnabled() {
      return this.editorMessageKey === 'cmd_enter';
    },
    enterToSendEnabled() {
      return this.editorMessageKey === 'enter';
    },
    conversationId() {
      return this.currentChat.id;
    },
    conversationIdByRoute() {
      return this.conversationId;
    },
    editorStateId() {
      return `draft-${this.conversationIdByRoute}-${this.effectiveReplyMode}`;
    },
    audioRecordFormat() {
      if (this.isAWhatsAppCloudChannel) {
        return AUDIO_FORMATS.OGG;
      }
      if (this.isAWhatsAppChannel || this.isATelegramChannel) {
        return AUDIO_FORMATS.MP3;
      }
      if (this.isAPIInbox) {
        return AUDIO_FORMATS.MP3;
      }
      return AUDIO_FORMATS.WAV;
    },
    messageVariables() {
      const variables = getMessageVariables({
        conversation: this.currentChat,
        contact: this.currentContact,
        inbox: this.inbox,
      });
      // Match the backend drops: names are Ruby-capitalized and
      // {{agent.*}} is the message sender, not the assignee.
      return {
        ...variables,
        ...getContactVariables(this.currentContact),
        ...getAgentVariables(this.currentUser),
      };
    },
    // ensure that the signature is plain text depending on `showRichContentEditor`
    signatureToApply() {
      return this.showRichContentEditor
        ? this.messageSignature
        : extractTextFromMarkdown(this.messageSignature);
    },
    connectedPortalSlug() {
      const { help_center: portal = {} } = this.inbox;
      const { slug = '' } = portal;
      return slug;
    },
    quotedReplyPreference() {
      if (!this.isAnEmailChannel) {
        return false;
      }

      return !!this.fetchQuotedReplyFlagFromUISettings(this.channelType);
    },
    lastEmailWithQuotedContent() {
      if (!this.isAnEmailChannel) {
        return null;
      }

      const lastEmail = this.lastEmail;
      if (!lastEmail || lastEmail.private) {
        return null;
      }

      return lastEmail;
    },
    quotedEmailText() {
      return extractQuotedEmailText(this.lastEmailWithQuotedContent);
    },
    quotedEmailPreviewText() {
      return truncatePreviewText(this.quotedEmailText, 80);
    },
    shouldShowQuotedReplyToggle() {
      return this.isAnEmailChannel && !this.isOnPrivateNote;
    },
    shouldShowQuotedPreview() {
      return (
        this.shouldShowQuotedReplyToggle &&
        this.quotedReplyPreference &&
        !!this.quotedEmailText
      );
    },
    isDefaultEditorMode() {
      return !this.showAudioRecorderEditor && !this.copilot.isActive.value;
    },
    isEditorDisabled() {
      return (
        (this.isAWhatsAppChannel || this.isAPIInbox) &&
        !this.isOnPrivateNote &&
        !this.currentChat.can_reply
      );
    },
  },
  watch: {
    currentChat(conversation, oldConversation) {
      if (oldConversation && oldConversation.id !== conversation.id) {
        // Only update email fields when switching to a completely different conversation (by ID)
        // This prevents overwriting user input (e.g., CC/BCC fields) when performing actions
        // like self-assign or other updates that do not actually change the conversation context
        this.setCCAndToEmailsFromLastChat();
        // Reset Copilot editor state (includes cancelling ongoing generation)
        this.copilot.reset();
      }

      if (this.isInstagramReplyRestricted) {
        this.replyType = REPLY_EDITOR_MODES.NOTE;
        return;
      }

      if (this.isOnPrivateNote) {
        return;
      }

      this.replyType = this.isWithinMessagingWindow
        ? REPLY_EDITOR_MODES.REPLY
        : REPLY_EDITOR_MODES.NOTE;

      this.fetchAndSetReplyTo();
    },
    // When moving from one conversation to another, the store may not have the
    // list of all the messages. A fetch is subsequently made to get the messages.
    // This watcher handles two main cases:
    // 1. When switching conversations and messages are fetched/updated, ensures CC/BCC fields are set from the latest OUTGOING/INCOMING email (not activity/private messages).
    // 2. Fixes and issue where CC/BCC fields could be reset/lost after assignment/activity actions or message mutations that did not represent a true email context change.
    lastEmail: {
      handler(lastEmail) {
        if (!lastEmail) return;
        this.setCCAndToEmailsFromLastChat();
      },
      deep: true,
    },
    conversationIdByRoute(conversationId, oldConversationId) {
      if (conversationId !== oldConversationId) {
        this.switchDraftContext(conversationId, this.effectiveReplyMode);
        this.resetRecorderAndClearAttachments();
      }
    },
    message(updatedMessage) {
      // Check if the message starts with a slash.
      const bodyWithoutSignature = removeSignature(
        updatedMessage,
        this.signatureToApply
      );
      const startsWithSlash = bodyWithoutSignature.startsWith('/');

      // Determine if the user is potentially typing a slash command.
      // This is true if the message starts with a slash and the rich content editor is not active.
      this.hasSlashCommand = startsWithSlash && !this.showRichContentEditor;
      this.showMentions = this.hasSlashCommand;

      // If a slash command is active, extract the command text after the slash.
      // If not, reset the mentionSearchKey.
      this.mentionSearchKey = this.hasSlashCommand
        ? bodyWithoutSignature.substring(1)
        : '';

      // Check for URLs in Apple Messages conversations
      this.checkForURLsInMessage(updatedMessage);

      // Autosave the current message draft.
      this.doAutoSaveDraft();
    },
    showWhatsappTemplates(isAvailable) {
      if (!isAvailable) this.hideWhatsappTemplatesModal();
    },
    showContentTemplates(isAvailable) {
      if (!isAvailable) this.hideContentTemplatesModal();
    },
    effectiveReplyMode(updatedReplyType) {
      this.$store.dispatch('draftMessages/setReplyEditorMode', {
        mode: updatedReplyType,
      });
      this.switchDraftContext(this.conversationIdByRoute, updatedReplyType);
    },
  },

  mounted() {
    if (this.isInstagramReplyRestricted) {
      this.replyType = REPLY_EDITOR_MODES.NOTE;
    }

    this.$store.dispatch('draftMessages/setReplyEditorMode', {
      mode: this.effectiveReplyMode,
    });
    this.switchDraftContext(
      this.conversationIdByRoute,
      this.effectiveReplyMode
    );
    // Don't use the keyboard listener mixin here as the events here are supposed to be
    // working even if the editor is focussed.
    document.addEventListener('paste', this.onPaste);
    document.addEventListener('keydown', this.handleKeyEvents);
    this.setCCAndToEmailsFromLastChat();
    this.doAutoSaveDraft = debounce(
      () => {
        this.saveDraft(this.conversationIdByRoute, this.effectiveReplyMode);
      },
      500,
      true
    );

    this.fetchAndSetReplyTo();
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);

    // A hacky fix to solve the drag and drop
    // Is showing on top of new conversation modal drag and drop
    // TODO need to find a better solution
    emitter.on(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.on(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.on(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  unmounted() {
    document.removeEventListener('paste', this.onPaste);
    document.removeEventListener('keydown', this.handleKeyEvents);
    emitter.off(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);
    emitter.off(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.off(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.off(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  methods: {
    getDraftKey(
      conversationId = this.conversationIdByRoute,
      replyType = this.effectiveReplyMode
    ) {
      return `draft-${conversationId}-${replyType}`;
    },
    getCopilotAcceptedMessage(replyType = this.effectiveReplyMode) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      return this.copilotAcceptedMessages[key] || '';
    },
    setCopilotAcceptedMessage(message, replyType = this.effectiveReplyMode) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      this.copilotAcceptedMessages[key] = trimContent(
        message || '',
        this.maxLength
      );
    },
    clearCopilotAcceptedMessage(replyType = this.effectiveReplyMode) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      delete this.copilotAcceptedMessages[key];
    },
    handleInsert(article) {
      const { url, title } = article;
      if (this.isRichEditorEnabled) {
        // Removing empty lines from the title
        const lines = title.split('\n');
        const nonEmptyLines = lines.filter(line => line.trim() !== '');
        const filteredMarkdown = nonEmptyLines.join(' ');
        emitter.emit(
          BUS_EVENTS.INSERT_INTO_RICH_EDITOR,
          `[${filteredMarkdown}](${url})`
        );
      } else {
        this.addIntoEditor(
          `${this.$t('CONVERSATION.REPLYBOX.INSERT_READ_MORE')} ${url}`
        );
      }

      useTrack(CONVERSATION_EVENTS.INSERT_ARTICLE_LINK);
    },
    toggleRichContentEditor() {
      this.updateUISettings({
        display_rich_content_editor: !this.showRichContentEditor,
      });

      const plainTextSignature = extractTextFromMarkdown(this.messageSignature);

      if (!this.showRichContentEditor && this.messageSignature) {
        // remove the old signature -> extract text from markdown -> attach new signature
        let message = removeSignature(this.message, this.messageSignature);
        message = extractTextFromMarkdown(message);
        message = appendSignature(message, plainTextSignature);

        this.message = message;
      } else {
        this.message = replaceSignature(
          this.message,
          plainTextSignature,
          this.messageSignature
        );
      }
    },
    toggleQuotedReply() {
      if (!this.isAnEmailChannel) {
        return;
      }

      const nextValue = !this.quotedReplyPreference;
      this.setQuotedReplyFlagForInbox(this.channelType, nextValue);
    },
    shouldIncludeQuotedEmail() {
      return (
        this.quotedReplyPreference &&
        this.shouldShowQuotedReplyToggle &&
        !!this.quotedEmailText
      );
    },
    getMessageWithQuotedEmailText(message) {
      if (!this.shouldIncludeQuotedEmail()) {
        return message;
      }

      const quotedText = this.quotedEmailText || '';
      const header = buildQuotedEmailHeader(
        this.lastEmailWithQuotedContent,
        this.currentContact,
        this.inbox
      );

      return appendQuotedTextToMessage(message, quotedText, header);
    },
    resetRecorderAndClearAttachments() {
      // Reset audio recorder UI state
      this.resetAudioRecorderInput();
      // Reset attached files
      this.attachedFiles = [];
    },
    saveDraft(conversationId, replyType) {
      if (this.message || this.message === '') {
        const key = this.getDraftKey(conversationId, replyType);
        const draftToSave = trimContent(this.message || '', this.maxLength);

        this.$store.dispatch('draftMessages/set', {
          key,
          message: draftToSave,
        });
      }
    },
    setToDraft(conversationId, replyType) {
      this.saveDraft(conversationId, replyType);
      this.message = '';
    },
    switchDraftContext(conversationId, replyMode) {
      if (
        this.draftConversationId === conversationId &&
        this.draftReplyMode === replyMode
      ) {
        return;
      }

      if (this.draftConversationId) {
        this.setToDraft(this.draftConversationId, this.draftReplyMode);
      }

      this.draftConversationId = conversationId;
      this.draftReplyMode = replyMode;
      this.getFromDraft();
    },
    getFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        const messageFromStore =
          this.$store.getters['draftMessages/get'](key) || '';

        // ensure that the message has signature set based on the ui setting
        this.message = this.toggleSignatureForDraft(messageFromStore);
      }
    },
    toggleSignatureForDraft(message) {
      if (this.isPrivate) {
        return message;
      }

      // Even when editor is disabled (e.g. WhatsApp/API can't reply), we must
      // still normalize stale signatures out of drafts when signature is off.
      if (this.isEditorDisabled && this.sendWithSignature) {
        return message;
      }

      const effectiveChannelType = getEffectiveChannelType(
        this.channelType,
        this.inbox?.medium || ''
      );

      return this.sendWithSignature
        ? appendSignature(message, this.messageSignature, effectiveChannelType)
        : removeSignature(message, this.messageSignature, effectiveChannelType);
    },
    removeFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        this.$store.dispatch('draftMessages/delete', { key });
      }
    },
    getElementToBind() {
      return this.replyEditor;
    },
    getKeyboardEvents() {
      return {
        Escape: {
          action: () => {
            this.hideEmojiPicker();
          },
          allowOnFocusedInput: true,
        },
        '$mod+KeyK': {
          action: e => {
            e.preventDefault();
            const ninja = document.querySelector('ninja-keys');
            ninja.open();
          },
          allowOnFocusedInput: true,
        },
        Enter: {
          action: e => {
            if (this.isAValidEvent('enter')) {
              this.onSendReply();
              e.preventDefault();
            }
          },
          allowOnFocusedInput: true,
        },
        '$mod+Enter': {
          action: () => {
            if (this.copilot.isActive.value && this.isFocused) {
              this.onSubmitCopilotReply();
            } else if (this.isAValidEvent('cmd_enter')) {
              this.onSendReply();
            }
          },
          allowOnFocusedInput: true,
        },
      };
    },
    isAValidEvent(selectedKey) {
      return (
        !this.showUserMentions &&
        !this.showMentions &&
        !this.showCannedMenu &&
        !this.showVariablesMenu &&
        !this.showMacrosMenu &&
        this.isFocused &&
        this.isEditorHotKeyEnabled(selectedKey)
      );
    },
    onPaste(e) {
      // Don't handle paste if compose new conversation modal is open
      if (this.newConversationModalActive) return;

      // Don't handle paste if editor is disabled
      if (this.isEditorDisabled) return;
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      // Filter valid files (non-zero size)
      Array.from(e.clipboardData.files)
        .filter(file => file.size > 0)
        .filter(file => {
          const isAllowed = isFileTypeAllowedForChannel(file, {
            channelType: this.channelType || this.inbox?.channel_type,
            medium: this.inbox?.medium,
            conversationType: this.conversationType,
            isInstagramChannel: this.isAnInstagramChannel,
            isOnPrivateNote: this.isOnPrivateNote,
          });

          if (!isAllowed) {
            useAlert(
              this.$t('CONVERSATION.FILE_TYPE_NOT_SUPPORTED', {
                fileName: file.name,
              })
            );
          }

          return isAllowed;
        })
        .forEach(file => {
          const { name, type, size } = file;
          this.onFileUpload({ name, type, size, file });
        });
    },
    toggleUserMention(currentMentionState) {
      this.showUserMentions = currentMentionState;
    },
    toggleCannedMenu(value) {
      this.showCannedMenu = value;
    },
    toggleVariablesMenu(value) {
      this.showVariablesMenu = value;
    },
    toggleMacrosMenu(value) {
      this.showMacrosMenu = value;
    },
    onExecuteMacro(macro) {
      const pending = this.macroExecution.execute(macro, this.currentChat.id);
      if (pending) {
        this.$refs.resolveAttributesModal?.open(
          pending.missing,
          pending.customAttributes
        );
      }
    },
    openWhatsappTemplateModal() {
      this.showWhatsAppTemplatesModal = true;
    },
    hideWhatsappTemplatesModal() {
      this.showWhatsAppTemplatesModal = false;
    },
    openContentTemplateModal() {
      this.showContentTemplatesModal = true;
    },
    hideContentTemplatesModal() {
      this.showContentTemplatesModal = false;
    },
    async confirmOnSendReply() {
      if (this.isReplyButtonDisabled) {
        return;
      }
      if (!this.showMentions) {
        const copilotAcceptedMessage = this.getCopilotAcceptedMessage();
        const isOnWhatsApp =
          this.isATwilioWhatsAppChannel ||
          this.isAWhatsAppCloudChannel ||
          this.is360DialogWhatsAppChannel;
        // Instagram and TikTok do not support sending text and attachments in the same message.
        // For Instagram, combining them causes duplicate messages due to separate echo events per component.
        // For TikTok, the API rejects messages that mix text and media.
        // To handle both cases, text and attachments are always sent as separate messages.
        const isOnInstagram = this.isAnInstagramChannel;
        const isOnTiktok = this.isATiktokChannel;

        // ✅ NEW: Auto-convert URLs to Rich Links for Apple Messages conversations
        if (
          this.isAppleMessagesConversation &&
          !this.isPrivate &&
          !this.hasAttachments
        ) {
          const detectedURLs = detectURLsInText(this.message);
          if (detectedURLs.length > 0) {
            // Process message to convert URLs to rich links
            try {
              // Add inbox to conversation object for App Clips detection
              const conversationWithInbox = {
                ...this.currentChat,
                inbox: this.inbox,
                inbox_id: this.inboxId,
              };

              const processedMessages = await processMessageForAppleMessages(
                this.message,
                conversationWithInbox,
                this.richLinkCachedData
              );

              // Clear the input immediately — messages are queued and send in background
              if (!this.isPrivate) {
                this.clearEmailField();
              }
              this.clearMessage();
              this.hideEmojiPicker();
              this.hideRichLinkPreview();
              this.$emit('update:popOutReplyBox', false);

              // Send processed messages (may be multiple: text + rich link)
              /* eslint-disable no-await-in-loop */
              for (let i = 0; i < processedMessages.length; i += 1) {
                const messagePart = processedMessages[i];
                const messagePayload = {
                  conversationId: this.currentChat.id,
                  message: messagePart.content,
                  private: false,
                  content_type: messagePart.content_type,
                  content_attributes: messagePart.content_attributes || {},
                };

                await this.$store.dispatch(
                  'createPendingMessageAndSend',
                  messagePayload
                );

                // Brief delay between messages (per Apple MSP docs)
                if (i < processedMessages.length - 1) {
                  await new Promise(resolve => {
                    setTimeout(resolve, 1500);
                  });
                }
              }
              /* eslint-enable no-await-in-loop */
              return;
            } catch (error) {
              // If URL processing fails, fall through to normal send
            }
          }
        }

        // Normal send flow (WhatsApp, Instagram, TikTok, or Apple Messages without URLs)
        if ((isOnWhatsApp || isOnInstagram || isOnTiktok) && !this.isPrivate) {
          this.sendMessageAsMultipleMessages(
            this.message,
            copilotAcceptedMessage
          );
        } else {
          const messagePayload = this.getMessagePayload(this.message);
          this.sendMessage(
            messagePayload,
            this.message,
            copilotAcceptedMessage
          );
        }

        if (!this.isPrivate) {
          this.clearEmailField();
        }
        this.$emit('update:popOutReplyBox', false);

        this.clearMessage();
        this.hideEmojiPicker();
      }
    },
    sendMessageAsMultipleMessages(message, copilotAcceptedMessage = '') {
      const messages = this.getMultipleMessagesPayload(message);
      messages.forEach(messagePayload => {
        this.sendMessage(
          messagePayload,
          messagePayload.message || '',
          copilotAcceptedMessage
        );
      });
    },
    sendMessageAnalyticsData(
      isPrivate,
      { editorMessage = '', copilotAcceptedMessage = '' } = {}
    ) {
      const normalizeForComparison = message => {
        let normalizedMessage = message || '';

        if (this.sendWithSignature && this.messageSignature && !isPrivate) {
          const effectiveChannelType = getEffectiveChannelType(
            this.channelType,
            this.inbox?.medium || ''
          );
          normalizedMessage = removeSignature(
            normalizedMessage,
            this.messageSignature,
            effectiveChannelType
          );
        }

        return trimContent(normalizedMessage);
      };

      const normalizedAcceptedMessage = normalizeForComparison(
        copilotAcceptedMessage
      );
      const normalizedEditorMessage = normalizeForComparison(editorMessage);

      if (normalizedAcceptedMessage && normalizedEditorMessage) {
        useTrack(CAPTAIN_EVENTS.AI_ASSISTED_MESSAGE_SENT, {
          conversationId: this.conversationIdByRoute,
          channelType: this.channelType,
          editedBeforeSend:
            normalizedAcceptedMessage !== normalizedEditorMessage,
          isPrivate,
        });
      }

      // Analytics data for message signature is enabled or not in channels
      return isPrivate
        ? useTrack(CONVERSATION_EVENTS.SENT_PRIVATE_NOTE)
        : useTrack(CONVERSATION_EVENTS.SENT_MESSAGE, {
            channelType: this.channelType,
            signatureEnabled: this.sendWithSignature,
            hasReplyTo: !!this.inReplyTo?.id,
          });
    },
    async onSendReply() {
      const undefinedVariables = getUndefinedVariablesInMessage({
        message: this.message,
        variables: this.messageVariables,
      });
      if (undefinedVariables.length > 0) {
        const undefinedVariablesCount =
          undefinedVariables.length > 1 ? undefinedVariables.length : 1;
        this.undefinedVariableMessage = this.$t(
          'CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.MESSAGE',
          {
            undefinedVariablesCount,
            undefinedVariables: undefinedVariables.join(', '),
          }
        );

        const ok = await this.$refs.confirmDialog.showConfirmation();
        if (ok) {
          this.confirmOnSendReply();
        }
      } else {
        this.confirmOnSendReply();
      }
    },
    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );
        emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE);
        emitter.emit(BUS_EVENTS.MESSAGE_SENT);
        this.removeFromDraft();
        this.sendMessageAnalyticsData(messagePayload.private, {
          editorMessage,
          copilotAcceptedMessage,
        });
      } catch (error) {
        const errorMessage =
          error?.response?.data?.error || this.$t('CONVERSATION.MESSAGE_ERROR');
        useAlert(errorMessage);
      }
    },
    async onSendWhatsAppReply(messagePayload) {
      // Check if this is a unified template - if so, use handleUnifiedTemplate
      if (messagePayload.templateParams?.source === 'unified') {
        this.hideContentTemplatesModal();
        await this.handleUnifiedTemplate(
          messagePayload.templateParams.template
        );
        return;
      }

      // For Twilio templates, use the standard send flow
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideWhatsappTemplatesModal();
    },
    async onSendContentTemplateReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideContentTemplatesModal();
    },
    replaceText(message) {
      // eslint-disable-next-line no-console
      console.log('[DEBUG replaceText] Called with message:', message);

      if (this.sendWithSignature && !this.private) {
        // if signature is enabled, append it to the message
        // appendSignature ensures that the signature is not duplicated
        // so we don't need to check if the signature is already present
        message = appendSignature(message, this.signatureToApply);
      }

      const updatedMessage = replaceVariablesInMessage({
        message,
        variables: this.messageVariables,
      });

      // eslint-disable-next-line no-console
      console.log('[DEBUG replaceText] Updated message:', updatedMessage);
      // eslint-disable-next-line no-console
      console.log(
        '[DEBUG replaceText] Current this.message before update:',
        this.message
      );

      setTimeout(() => {
        useTrack(CONVERSATION_EVENTS.INSERTED_A_CANNED_RESPONSE);
        this.message = updatedMessage;
        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG replaceText] this.message after update:',
          this.message
        );

        // Hide the slash command menu after inserting text
        this.hideMentions();
      }, 100);
    },
    handleTemplateSelect(item) {
      if (item.type === 'canned') {
        // Handle canned response - just replace text
        this.replaceText(item.content);
      } else if (item.type === 'template') {
        // Clear the editor text before the async send so that the message watcher
        // (which runs next-tick in Vue 3) sees an empty message and does not
        // re-show the dropdown after hideMentions() has closed it.
        this.clearMessage();
        this.handleUnifiedTemplate(item.template);
      }

      // Hide the mentions menu immediately when a template is selected
      this.hideMentions();
    },
    async handleUnifiedTemplate(template) {
      try {
        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] Starting with template:',
          template
        );

        // Always fetch full template data to see content blocks
        const fullTemplate = await this.$store.dispatch(
          'messageTemplates/show',
          {
            id: template.id,
          }
        );

        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] Full template fetched:',
          fullTemplate
        );

        // FIRST: Check if template has attachments
        // Templates with attachments should be sent as messages, not inserted as text
        const hasAttachments =
          fullTemplate.attachmentsSummary &&
          fullTemplate.attachmentsSummary.length > 0;

        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] hasAttachments:',
          hasAttachments
        );

        if (hasAttachments) {
          const messageData = {
            content: '', // Empty content - backend will handle placeholder text
            content_type: 'text',
            content_attributes: {},
            template_id: fullTemplate.id,
          };

          await this.sendAppleMessage(messageData);
          return;
        }

        // Check if this is an Apple Messages interactive template
        // Interactive templates have specific content structures:
        // - type field (explicit type like 'list_picker', 'time_picker', 'form', etc.)
        // - OR specific structure patterns (images/replies for quick reply, etc.)
        // - OR content_attributes with the structure inside
        const content = fullTemplate.content;
        const contentAttrs =
          content?.content_attributes || content?.contentAttributes;

        // eslint-disable-next-line no-console
        console.log('[DEBUG handleUnifiedTemplate] content:', content);
        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] contentAttrs:',
          contentAttrs
        );

        // Check if content is an array (multi-block template)
        const isArrayContent = Array.isArray(content);

        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] isArrayContent:',
          isArrayContent
        );

        // For array content, check if any block is interactive
        let hasInteractiveBlock = false;
        if (isArrayContent) {
          hasInteractiveBlock = content.some(
            block =>
              block.type === 'quick_reply' ||
              block.type === 'interactive' ||
              block.type === 'list_picker' ||
              block.type === 'time_picker' ||
              block.type === 'form' ||
              block.items ||
              block.replies ||
              block.sections ||
              block.timeslots
          );
        }

        const isAppleInteractive = !!(
          (
            fullTemplate.supportedChannels?.includes(
              'apple_messages_for_business'
            ) &&
            ((isArrayContent && hasInteractiveBlock) || // Array with interactive blocks
              (content &&
                (content.type || // Explicit type field
                  content.content_type || // Explicit content_type field
                  content.items || // Quick reply structure (new format)
                  content.replies || // Quick reply structure (legacy format)
                  content.list_picker || // List picker structure (nested)
                  content.time_picker || // Time picker structure (nested)
                  content.event || // Time picker structure (with event object)
                  content.form || // Form structure (legacy nested format)
                  content.pages || // Form structure (new block editor format)
                  content.apple_pay || // Apple Pay structure
                  // AMB UPGRADE NOTE: Do NOT require `images` here. MetadataStrategy#load_data
                  // calls .except('images') so images are never present in build_content output.
                  // Sections alone is the correct discriminator for list_pickers.
                  content.sections || // List picker structure (direct)
                  (content.timeslots && content.timeslots.length > 0) || // Time picker structure (direct)
                  contentAttrs?.sections || // List picker in content_attributes
                  (contentAttrs?.timeslots &&
                    contentAttrs.timeslots.length > 0) || // Time picker in content_attributes
                  contentAttrs?.event || // Time picker with event in content_attributes
                  contentAttrs?.pages || // Forms with pages in content_attributes
                  contentAttrs?.form || // Forms with form in content_attributes
                  contentAttrs?.replies || // Quick reply in content_attributes
                  contentAttrs?.items)))
          ) // Quick reply items in content_attributes
        );

        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] isAppleInteractive:',
          isAppleInteractive
        );
        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] this.isAppleMessagesConversation:',
          this.isAppleMessagesConversation
        );

        if (isAppleInteractive && this.isAppleMessagesConversation) {
          // eslint-disable-next-line no-console
          console.log(
            '[DEBUG handleUnifiedTemplate] SENDING as Apple Interactive template'
          );
          // This is an Apple Messages interactive template - send it directly

          // Check if this is an array-based template (content is an array of blocks)
          if (isArrayContent) {
            // Process each block in sequence
            /* eslint-disable no-await-in-loop */
            for (let i = 0; i < content.length; i += 1) {
              const block = content[i];

              // Show typing indicator before sending (except for first block)
              if (i > 0) {
                this.$store.dispatch('conversationTypingStatus/toggleTyping', {
                  conversationId: this.currentChat.id,
                  status: 'on',
                  isPrivate: false,
                });

                // Wait 3500ms with typing indicator visible
                await new Promise(resolve => {
                  setTimeout(resolve, 3500);
                });

                // Turn off typing indicator
                this.$store.dispatch('conversationTypingStatus/toggleTyping', {
                  conversationId: this.currentChat.id,
                  status: 'off',
                  isPrivate: false,
                });

                // Small pause after turning off typing
                await new Promise(resolve => {
                  setTimeout(resolve, 200);
                });
              }

              // Text block - just has content property
              if (
                block.content &&
                !block.type &&
                !block.items &&
                !block.replies
              ) {
                // Send text block as a regular message
                const textPayload = {
                  conversationId: this.currentChat.id,
                  message: block.content,
                  private: false,
                };
                await this.sendMessage(textPayload);

                // Longer delay after text message to let it render and be read
                // Only add delay if this isn't the last block
                if (i < content.length - 1) {
                  await new Promise(resolve => {
                    setTimeout(resolve, 1000);
                  });
                }
              } else if (
                block.items ||
                block.replies ||
                block.type === 'quick_reply'
              ) {
                // Quick reply block
                const items = block.items || block.replies || [];
                const messageData = {
                  type: 'quick_reply',
                  content_type: 'apple_quick_reply',
                  content_attributes: {
                    summary_text: block.summary_text || block.summaryText || '',
                    items: items.map((item, index) => ({
                      title: item.title,
                      identifier: item.identifier || `reply_${index}`,
                    })),
                    received_title:
                      block.received_title ||
                      block.receivedTitle ||
                      'Please select an option',
                    received_subtitle:
                      block.received_subtitle || block.receivedSubtitle || '',
                    reply_title: block.reply_title || block.replyTitle || '',
                    reply_subtitle:
                      block.reply_subtitle || block.replySubtitle || '',
                  },
                };
                await this.sendAppleMessage(messageData);
              } else if (block.type === 'list_picker' || block.sections) {
                // List picker block
                const messageData = {
                  type: 'list_picker',
                  content_type: 'apple_list_picker',
                  content_attributes: block,
                };
                await this.sendAppleMessage(messageData);
              } else if (block.type === 'time_picker' || block.timeslots) {
                // Time picker block
                const messageData = {
                  type: 'time_picker',
                  content_type: 'apple_time_picker',
                  content_attributes: block,
                };
                await this.sendAppleMessage(messageData);
              }
            }
            /* eslint-enable no-await-in-loop */
            return;
          }

          // Single interactive message - detect the message type and wrap the content appropriately

          let messageData;
          if (
            (content.content_type || content.contentType) &&
            (content.content_attributes || content.contentAttributes)
          ) {
            // Content already has content_type and content_attributes
            // Check if this is a template type that needs render API for image loading
            const contentType = content.content_type || content.contentType;
            const needsRenderAPI =
              contentType === 'apple_list_picker' ||
              contentType === 'apple_time_picker' ||
              contentType === 'apple_form';

            if (needsRenderAPI) {
              // Call render API to fetch images and ensure proper format
              const rendered = await this.$store.dispatch(
                'messageTemplates/render',
                {
                  templateId: fullTemplate.id,
                  parameters: {}, // No dynamic parameters for these templates
                  channelType:
                    this.currentChat?.inbox?.channel_type ||
                    'apple_messages_for_business',
                }
              );

              const renderedData = rendered.data || rendered;

              if (renderedData?.content_attributes) {
                messageData = {
                  content_type: renderedData.content_type || contentType,
                  content_attributes: renderedData.content_attributes,
                  type: content.type,
                  template_id: fullTemplate.id,
                };
              } else {
                // Fallback to direct content if render fails
                messageData = {
                  content_type: contentType,
                  content_attributes:
                    content.content_attributes || content.contentAttributes,
                  type: content.type,
                };
              }
            } else {
              // Use content directly for non-template types
              messageData = {
                content_type: contentType,
                content_attributes:
                  content.content_attributes || content.contentAttributes,
                type: content.type,
              };
            }
          } else if (content.type) {
            // Content has explicit type - use it directly
            messageData = content;
          } else if (
            content.items ||
            content.replies ||
            contentAttrs?.items ||
            contentAttrs?.replies
          ) {
            // Quick reply structure - normalize to the format backend expects
            // Check both top-level and content_attributes for items/replies
            const items =
              content.items ||
              content.replies ||
              contentAttrs?.items ||
              contentAttrs?.replies ||
              [];
            const summaryText =
              content.summaryText ||
              content.summary_text ||
              contentAttrs?.text ||
              '';

            messageData = {
              type: 'quick_reply',
              content_type: 'apple_quick_reply',
              content_attributes: {
                summary_text: summaryText,
                items: items.map((item, index) => ({
                  title: item.title,
                  identifier: item.identifier || `reply_${index}`,
                })),
                received_title: summaryText || 'Please select an option',
                received_subtitle: '',
                reply_title: '',
                reply_subtitle: '',
              },
            };
          } else if (
            // AMB UPGRADE NOTE: sections alone identifies a list_picker.
            // MetadataStrategy#load_data strips images (.except('images')), so
            // (sections && images) would never match metadata-stored templates.
            content.list_picker ||
            content.listPicker ||
            content.sections ||
            contentAttrs?.sections
          ) {
            // List picker structure - use render API to fetch images from database
            // This ensures images are base64-encoded and properly formatted

            const rendered = await this.$store.dispatch(
              'messageTemplates/render',
              {
                templateId: fullTemplate.id,
                parameters: {}, // No dynamic parameters for list pickers
                channelType:
                  this.currentChat?.inbox?.channel_type ||
                  'apple_messages_for_business',
              }
            );

            const renderedData = rendered.data || rendered;

            if (renderedData?.content_attributes) {
              messageData = {
                type: 'list_picker',
                content_type: 'apple_list_picker',
                content_attributes: renderedData.content_attributes,
                // Include template_id so backend can attach template files
                template_id: fullTemplate.id,
              };
            } else {
              // Fallback to direct content if rendering fails
              const listPickerData =
                content.list_picker ||
                content.listPicker ||
                contentAttrs ||
                content;

              messageData = {
                type: 'list_picker',
                content_type: 'apple_list_picker',
                content_attributes: {
                  sections: listPickerData.sections || [],
                  images: listPickerData.images || [],
                  received_title:
                    listPickerData.received_title ||
                    listPickerData.receivedTitle ||
                    'Please select an option',
                  received_subtitle:
                    listPickerData.received_subtitle ||
                    listPickerData.receivedSubtitle ||
                    '',
                  received_image_identifier:
                    listPickerData.received_image_identifier ||
                    listPickerData.receivedImageIdentifier ||
                    '',
                  received_style:
                    listPickerData.received_style ||
                    listPickerData.receivedStyle ||
                    'icon',
                  reply_title:
                    listPickerData.reply_title ||
                    listPickerData.replyTitle ||
                    'Selection Made',
                  reply_subtitle:
                    listPickerData.reply_subtitle ||
                    listPickerData.replySubtitle ||
                    '',
                  reply_style:
                    listPickerData.reply_style ||
                    listPickerData.replyStyle ||
                    'icon',
                  reply_image_title:
                    listPickerData.reply_image_title ||
                    listPickerData.replyImageTitle ||
                    '',
                  reply_image_subtitle:
                    listPickerData.reply_image_subtitle ||
                    listPickerData.replyImageSubtitle ||
                    '',
                  reply_secondary_subtitle:
                    listPickerData.reply_secondary_subtitle ||
                    listPickerData.replySecondarySubtitle ||
                    '',
                  reply_tertiary_subtitle:
                    listPickerData.reply_tertiary_subtitle ||
                    listPickerData.replyTertiarySubtitle ||
                    '',
                },
              };
            }
          } else if (
            content.time_picker ||
            content.timePicker ||
            content.event || // Time picker with event object
            (content.timeslots && content.timeslots.length > 0) ||
            (contentAttrs?.timeslots && contentAttrs.timeslots.length > 0) ||
            contentAttrs?.event // Time picker with event in content_attributes
          ) {
            // ALWAYS use render API for time pickers to ensure proper formatting
            // The adapter's format_timeslots method handles identifier → start_time conversion
            // and ensures the payload matches Apple MSP requirements

            // Get parameters for rendering
            let parameters = {};

            // If template has saved timeslots in content_blocks, extract them as available_slots
            const savedTimeslots =
              content.event?.timeslots ||
              content.timeslots ||
              contentAttrs?.event?.timeslots ||
              contentAttrs?.timeslots;

            if (savedTimeslots && savedTimeslots.length > 0) {
              // Convert saved timeslots to available_slots parameter format
              parameters.available_slots = savedTimeslots;
            } else {
              // No saved timeslots - use default dynamic slots
              const tomorrow = new Date();
              tomorrow.setDate(tomorrow.getDate() + 1);
              tomorrow.setHours(9, 0, 0, 0);

              parameters = {
                available_slots: [
                  new Date(tomorrow.getTime()).toISOString(),
                  new Date(
                    tomorrow.getTime() + 2 * 60 * 60 * 1000
                  ).toISOString(),
                  new Date(
                    tomorrow.getTime() + 4 * 60 * 60 * 1000
                  ).toISOString(),
                ],
              };
            }

            const rendered = await this.$store.dispatch(
              'messageTemplates/render',
              {
                templateId: fullTemplate.id,
                parameters,
                channelType:
                  this.currentChat?.inbox?.channel_type ||
                  'apple_messages_for_business',
              }
            );

            const renderedData = rendered.data || rendered;

            if (renderedData?.content_attributes) {
              messageData = {
                type: 'time_picker',
                content_type: 'apple_time_picker',
                content_attributes: renderedData.content_attributes,
                // Include template_id so backend can attach template files
                template_id: fullTemplate.id,
              };
            } else {
              // Fallback to stored content if rendering fails
              const timePickerData =
                content.time_picker ||
                content.timePicker ||
                contentAttrs ||
                content;

              const normalizeKeys = obj => {
                if (!obj || typeof obj !== 'object') return obj;
                if (Array.isArray(obj)) return obj.map(normalizeKeys);

                const normalized = {};
                Object.keys(obj).forEach(key => {
                  const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
                  normalized[snakeKey] = normalizeKeys(obj[key]);
                });
                return normalized;
              };

              const normalizedAttrs = normalizeKeys(timePickerData);
              delete normalizedAttrs.images;

              messageData = {
                type: 'time_picker',
                content_type: 'apple_time_picker',
                content_attributes: normalizedAttrs,
              };
            }
          } else if (
            content.form ||
            (content.pages &&
              (content.received_message || content.receivedMessage)) ||
            contentAttrs?.form ||
            (contentAttrs?.pages &&
              (contentAttrs?.received_message || contentAttrs?.receivedMessage))
          ) {
            // Form structure - use render API to fetch images from database
            // This ensures images are base64-encoded and properly formatted

            const rendered = await this.$store.dispatch(
              'messageTemplates/render',
              {
                templateId: fullTemplate.id,
                parameters: {}, // No dynamic parameters for forms
                channelType:
                  this.currentChat?.inbox?.channel_type ||
                  'apple_messages_for_business',
              }
            );

            const renderedData = rendered.data || rendered;

            if (renderedData?.content_attributes) {
              messageData = {
                type: 'form',
                content_type: 'apple_form',
                content_attributes: renderedData.content_attributes,
                // Include template_id so backend can attach template files
                template_id: fullTemplate.id,
              };
            } else {
              // Fallback to direct content if rendering fails
              messageData = {
                type: 'form',
                content_type: 'apple_form',
                content_attributes: content,
              };
            }
          } else if (content.apple_pay || content.applePay) {
            // Apple Pay structure
            messageData = {
              type: 'apple_pay',
              content_type: 'apple_pay',
              content_attributes: content,
            };
          } else {
            // Unknown structure - use as-is
            messageData = content;
          }

          // Clean up images array - remove base64 data and preview, keep only identifiers
          if (messageData.content_attributes?.images) {
            // Check if images is an object (dictionary) or array
            const imagesData = messageData.content_attributes.images;

            if (Array.isArray(imagesData)) {
              // Array format - map over items
              messageData.content_attributes.images = imagesData.map(img => ({
                identifier: img.identifier,
                description: img.description || '',
                data: img.data,
              }));
            } else if (typeof imagesData === 'object') {
              // Object/dictionary format (keys are identifiers, values are base64 strings)
              // Convert to array format expected by backend

              messageData.content_attributes.images = Object.entries(
                imagesData
              ).map(([identifier, data]) => ({
                identifier: identifier,
                description: '',
                data: data,
              }));
            }
          }

          // Include template_id so backend can attach template files if present
          messageData.template_id = fullTemplate.id;

          // For time pickers, remove images from content_attributes
          // Images are loaded by backend via template_id attachments
          // Time picker validator doesn't allow images in content_attributes
          if (
            messageData.type === 'time_picker' &&
            messageData.content_attributes?.images
          ) {
            delete messageData.content_attributes.images;
          }

          await this.sendAppleMessage(messageData);
          return;
        }

        // eslint-disable-next-line no-console
        console.log(
          '[DEBUG handleUnifiedTemplate] NOT sending as interactive - will render and insert as text'
        );

        // For templates without parameters, render and insert
        const hasParameters =
          fullTemplate.parameters &&
          Object.keys(fullTemplate.parameters).length > 0;

        // Check if all parameters have default values
        const allParametersHaveDefaults = hasParameters
          ? Object.values(fullTemplate.parameters).every(
              param => param.default !== undefined
            )
          : false;

        // Build default parameters object
        const defaultParameters = {};
        if (hasParameters) {
          Object.entries(fullTemplate.parameters).forEach(([key, config]) => {
            if (config.default !== undefined) {
              defaultParameters[key] = config.default;
            }
          });
        }

        if (!hasParameters || allParametersHaveDefaults) {
          // Simple template without parameters OR all parameters have defaults
          // Render and insert as text
          // eslint-disable-next-line no-console
          console.log(
            '[DEBUG handleUnifiedTemplate] Rendering template for text insertion'
          );

          const response = await this.$store.dispatch(
            'messageTemplates/render',
            {
              templateId: fullTemplate.id,
              parameters: defaultParameters,
              channelType: this.channelType,
            }
          );

          // eslint-disable-next-line no-console
          console.log(
            '[DEBUG handleUnifiedTemplate] Render response:',
            response
          );

          if (response.data.content) {
            // eslint-disable-next-line no-console
            console.log(
              '[DEBUG handleUnifiedTemplate] Calling replaceText with:',
              response.data.content
            );
            this.replaceText(response.data.content);
          } else {
            // eslint-disable-next-line no-console
            console.log(
              '[DEBUG handleUnifiedTemplate] NO CONTENT in response.data.content'
            );
          }
        } else {
          // Template with parameters that need user input
          this.$store.dispatch('alerts/show', {
            message: this.$t('CONVERSATION.TEMPLATE_REQUIRES_PARAMETERS', {
              name: fullTemplate.name,
            }),
            type: 'info',
          });
          // TODO: Open a modal to collect parameters
        }
      } catch (error) {
        this.$store.dispatch('alerts/show', {
          message: error?.message || 'Failed to load template',
          type: 'error',
        });
      }
    },
    setReplyMode(mode = REPLY_EDITOR_MODES.REPLY) {
      // Clear attachments when switching between private note and reply modes
      // This is to prevent from breaking the upload rules
      if (this.attachedFiles.length > 0) this.attachedFiles = [];

      this.$store.dispatch('draftMessages/setReplyEditorMode', { mode });
      if (this.canSendPublicReply) this.replyType = mode;
      if (this.isRecordingAudio) {
        this.toggleAudioRecorder();
      }
    },
    clearEditorSelection() {
      this.updateEditorSelectionWith = '';
    },
    addIntoEditor(content) {
      this.updateEditorSelectionWith = content;
      this.onFocus();
    },
    executeCopilotAction(action, data) {
      this.copilot.execute(action, data);
    },
    clearMessage() {
      this.message = '';
      this.clearCopilotAcceptedMessage();
      if (this.sendWithSignature && !this.isPrivate) {
        // if signature is enabled, append it to the message
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        this.message = appendSignature(
          this.message,
          this.messageSignature,
          effectiveChannelType
        );
      }
      this.attachedFiles = [];
      this.isRecordingAudio = false;
      this.resetReplyToMessage();
      this.resetAudioRecorderInput();
    },
    clearEmailField() {
      this.ccEmails = '';
      this.bccEmails = '';
      this.toEmails = '';
    },

    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    toggleAudioRecorder() {
      this.isRecordingAudio = !this.isRecordingAudio;
      this.isRecorderAudioStopped = !this.isRecordingAudio;
      if (!this.isRecordingAudio) {
        this.resetAudioRecorderInput();
      }
    },
    toggleAudioRecorderPlayPause() {
      if (!this.isRecordingAudio) {
        return;
      }
      if (!this.isRecorderAudioStopped) {
        this.isRecorderAudioStopped = true;
        if (!this.$refs.audioRecorderInput) return;
        this.$refs.audioRecorderInput.stopRecording();
      } else if (this.isRecorderAudioStopped) {
        this.$refs.audioRecorderInput.playPause();
      }
    },
    hideEmojiPicker() {
      if (this.showEmojiPicker) {
        this.toggleEmojiPicker();
      }
    },
    hideMentions() {
      this.showMentions = false;
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onBlur() {
      this.isFocused = false;
      this.saveDraft(this.conversationIdByRoute, this.effectiveReplyMode);
    },
    onFocus() {
      this.isFocused = true;
    },
    onRecordProgressChanged(duration) {
      this.recordingAudioDurationText = duration;
    },
    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      this.hasRecordedAudio = true;
      // Added a new key isVoiceMessage to the file to identify recorded audio
      // Because to filter and show only non recorded audio and other attachments
      const autoRecordedFile = {
        ...file,
        isVoiceMessage: true,
      };
      return file && this.onFileUpload(autoRecordedFile);
    },
    onRecordError() {
      this.toggleAudioRecorder();
      useAlert(this.$t('CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED'));
    },
    toggleTyping(status) {
      const conversationId = this.currentChat.id;
      const isPrivate = this.isPrivate;

      if (!conversationId) {
        return;
      }

      this.$store.dispatch('conversationTypingStatus/toggleTyping', {
        status,
        conversationId,
        isPrivate,
      });
    },
    attachFile({ blob, file }) {
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      const reader = new FileReader();
      reader.readAsDataURL(file.file);
      reader.onloadend = () => {
        this.attachedFiles.push({
          currentChatId: this.currentChat.id,
          resource: blob || file,
          isPrivate: this.isPrivate,
          thumb: reader.result,
          blobSignedId: blob ? blob.signed_id : undefined,
          isVoiceMessage: file?.isVoiceMessage || false,
        });
      };
    },
    removeAttachment(attachments) {
      this.attachedFiles = attachments;
    },
    setReplyToInPayload(payload) {
      if (this.inReplyTo?.id) {
        return {
          ...payload,
          contentAttributes: {
            ...payload.contentAttributes,
            in_reply_to: this.inReplyTo.id,
          },
        };
      }

      return payload;
    },
    getMultipleMessagesPayload(message) {
      const multipleMessagePayload = [];

      if (this.attachedFiles && this.attachedFiles.length) {
        let caption =
          this.isAnInstagramChannel || this.isATiktokChannel ? '' : message;
        this.attachedFiles.forEach(attachment => {
          const attachedFile = this.globalConfig.directUploadsEnabled
            ? attachment.blobSignedId
            : attachment.resource.file;
          let attachmentPayload = {
            conversationId: this.currentChat.id,
            files: [attachedFile],
            private: false,
            message: caption,
            sender: this.sender,
            isVoiceMessage: attachment.isVoiceMessage || false,
          };

          attachmentPayload = this.setReplyToInPayload(attachmentPayload);
          multipleMessagePayload.push(attachmentPayload);
          // For WhatsApp, only the first attachment gets a caption
          if (!this.isAnInstagramChannel) caption = '';
        });
      }

      const hasNoAttachments =
        !this.attachedFiles || !this.attachedFiles.length;
      // For Instagram and TikTok, text must always be sent as a separate message (no captions on attachments).
      // For WhatsApp, we only need a text message if there are no attachments.
      if (
        ((this.isAnInstagramChannel || this.isATiktokChannel) &&
          this.message) ||
        (!(this.isAnInstagramChannel || this.isATiktokChannel) &&
          hasNoAttachments)
      ) {
        let messagePayload = {
          conversationId: this.currentChat.id,
          message,
          private: false,
          sender: this.sender,
        };

        messagePayload = this.setReplyToInPayload(messagePayload);

        multipleMessagePayload.push(messagePayload);
      }

      return multipleMessagePayload;
    },
    getMessagePayload(message) {
      // Normalize URLs in message for Apple Messages conversations
      let processedMessage = message;
      if (this.isAppleMessagesConversation) {
        const detectedURLs = detectURLsInText(message);
        if (detectedURLs.length > 0) {
          // Replace URLs in the message with normalized versions
          const originalUrls = message.match(URL_REGEX) || [];
          detectedURLs.forEach((normalizedUrl, index) => {
            if (originalUrls[index]) {
              processedMessage = processedMessage.replace(
                originalUrls[index],
                normalizedUrl
              );
            }
          });
        }
      }

      // Apply quoted email text for email channels
      const messageWithQuote =
        this.getMessageWithQuotedEmailText(processedMessage);

      let messagePayload = {
        conversationId: this.currentChat.id,
        message: messageWithQuote,
        private: this.isPrivate,
        sender: this.sender,
      };
      messagePayload = this.setReplyToInPayload(messagePayload);

      if (this.attachedFiles && this.attachedFiles.length) {
        messagePayload.files = [];
        this.attachedFiles.forEach(attachment => {
          if (this.globalConfig.directUploadsEnabled) {
            messagePayload.files.push(attachment.blobSignedId);
            if (attachment.isVoiceMessage) {
              messagePayload.isVoiceMessage = true;
            }
          } else {
            messagePayload.files.push(attachment.resource.file);
          }
        });
      }

      if (this.ccEmails && !this.isOnPrivateNote) {
        messagePayload.ccEmails = this.ccEmails;
      }

      if (this.bccEmails && !this.isOnPrivateNote) {
        messagePayload.bccEmails = this.bccEmails;
      }

      if (this.toEmails && !this.isOnPrivateNote) {
        messagePayload.toEmails = this.toEmails;
      }
      return messagePayload;
    },
    setCcEmails(value) {
      this.bccEmails = value.bccEmails;
      this.ccEmails = value.ccEmails;
    },
    setCCAndToEmailsFromLastChat() {
      const conversationContact = this.currentChat?.meta?.sender?.email || '';
      const { email: inboxEmail, forward_to_email: forwardToEmail } =
        this.inbox;

      const { cc, bcc, to } = getRecipients(
        this.lastEmail,
        conversationContact,
        inboxEmail,
        forwardToEmail
      );

      this.toEmails = to.join(', ');
      this.ccEmails = cc.join(', ');
      this.bccEmails = bcc.join(', ');
    },
    fetchAndSetReplyTo() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      const replyToMessageId = LocalStorage.getFromJsonStore(
        replyStorageKey,
        this.conversationId
      );

      this.inReplyTo = this.currentChat?.messages?.find(message => {
        if (message.id === replyToMessageId) {
          return true;
        }
        return false;
      });
    },
    resetReplyToMessage() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      LocalStorage.deleteFromJsonStore(replyStorageKey, this.conversationId);
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE);
    },
    onNewConversationModalActive(isActive) {
      // Issue is if the new conversation modal is open and we drag and drop the file
      // then the file is not getting attached to the new conversation modal
      // and it is getting attached to the current conversation reply box
      // so to fix this we are removing the drag and drop event listener from the current conversation reply box
      // When new conversation modal is open
      this.newConversationModalActive = isActive;
    },
    onSearchPopoverClose() {
      this.showArticleSearchPopover = false;
    },
    toggleInsertArticle() {
      this.showArticleSearchPopover = !this.showArticleSearchPopover;
    },
    resetAudioRecorderInput() {
      this.recordingAudioDurationText = '00:00';
      this.isRecordingAudio = false;
      this.recordingAudioState = '';
      this.hasRecordedAudio = false;
      // Only clear the recorded audio when we click toggle button.
      this.attachedFiles = this.attachedFiles.filter(
        file => !file?.isVoiceMessage
      );
    },
    toggleEditorSize() {
      this.$emit('toggleEditorSize');
      this.$nextTick(() => this.messageEditor?.focusEditorInputField());
    },
    togglePopout() {
      this.$emit('update:popOutReplyBox', !this.popOutReplyBox);
    },
    onSubmitCopilotReply() {
      const acceptedMessage = this.copilot.accept();
      this.message = acceptedMessage;
      this.setCopilotAcceptedMessage(acceptedMessage);
    },
    async sendAppleMessage(messageData) {
      // eslint-disable-next-line no-console
      console.log(
        '[DEBUG ReplyBox] Received messageData:',
        JSON.parse(JSON.stringify(messageData))
      );
      try {
        // Handle content: allow empty string for attachment-only messages
        let messageContent = 'Apple Message'; // default fallback
        if (messageData.content !== undefined && messageData.content !== null) {
          messageContent = messageData.content; // Use provided content (even if empty string)
        } else if (messageData.summary_text) {
          messageContent = messageData.summary_text;
        }

        const messagePayload = {
          conversationId: this.currentChat.id,
          message: messageContent,
          content_type: messageData.content_type,
          content_attributes: messageData.content_attributes,
          private: false,
        };

        // Include template_id if present (for template attachments)
        if (messageData.template_id) {
          messagePayload.template_id = messageData.template_id;
        }

        // Use createPendingMessageAndSend directly to ensure proper message creation
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );

        this.clearMessage();
        this.hideEmojiPicker();

        // Note: Tracking removed to avoid $track dependency issues
      } catch (error) {
        const errorMessage =
          error.response?.data?.error ||
          error.response?.data?.message ||
          error?.message ||
          this.$t('CONVERSATION.MESSAGE_ERROR');
        this.$store.dispatch('alerts/show', {
          message: errorMessage,
          type: 'error',
        });
      }
    },

    // Rich Link URL detection methods
    checkForURLsInMessage(message) {
      if (!this.isAppleMessagesConversation || !message) {
        this.hideRichLinkPreview();
        return;
      }

      // Clear existing timeout
      if (this.richLinkDetectionTimeout) {
        clearTimeout(this.richLinkDetectionTimeout);
      }

      // Debounce URL detection
      this.richLinkDetectionTimeout = setTimeout(() => {
        // Use the enhanced URL detection from appleMessagesRichLink helper
        const detectedURLs = detectURLsInText(message);

        if (detectedURLs.length > 0) {
          const url = detectedURLs[0]; // Use first detected URL (already normalized)
          // Check if URL should trigger Rich Link preview
          const urlRatio = url.length / message.length;
          if (urlRatio > 0.3) {
            // Show preview if URL is significant part of message
            this.showRichLinkPreviewForUrl(url);
          } else {
            this.hideRichLinkPreview();
          }
        } else {
          this.hideRichLinkPreview();
        }
      }, 500);
    },

    showRichLinkPreviewForUrl(url) {
      this.richLinkPreviewUrl = url;
      this.showRichLinkPreview = true;
    },

    hideRichLinkPreview() {
      this.showRichLinkPreview = false;
      this.richLinkPreviewUrl = '';
      this.richLinkCachedData = null;
    },

    onRichLinkSendAsText(message) {
      // Send as regular text message
      this.message = message;
      this.onSendReply();
    },

    async onRichLinkSendAsRichLink(data) {
      try {
        // ✅ FIX: Process the message to split text and URLs properly
        const messageContent = data.originalMessage;
        const conversation = this.currentChat;

        // Use the processMessageForAppleMessages function to split the message
        const processedMessages = await processMessageForAppleMessages(
          messageContent,
          conversation
        );

        // Process messages sequentially with delay per Apple MSP docs

        if (processedMessages.length === 1) {
          // Single message (likely combined rich link) - send directly
          const messagePayload = {
            conversationId: this.currentChat.id,
            message: processedMessages[0].content,
            private: false,
            content_type: processedMessages[0].content_type,
            content_attributes: processedMessages[0].content_attributes || {},
          };

          // Send single combined message

          await this.$store.dispatch(
            'createPendingMessageAndSend',
            messagePayload
          );
        } else {
          // Multiple messages - send sequentially with delays
          /* eslint-disable no-await-in-loop */
          for (let i = 0; i < processedMessages.length; i += 1) {
            const messagePart = processedMessages[i];
            const messagePayload = {
              conversationId: this.currentChat.id,
              message: messagePart.content,
              private: false,
              content_type: messagePart.content_type,
              content_attributes: messagePart.content_attributes || {},
            };

            // Send message part
            await this.$store.dispatch(
              'createPendingMessageAndSend',
              messagePayload
            );

            // Brief delay between messages (per Apple MSP docs)
            if (i < processedMessages.length - 1) {
              /* eslint-disable no-promise-executor-return */
              await new Promise(resolve => {
                setTimeout(resolve, 1500);
              });
              /* eslint-enable no-promise-executor-return */
            }
          }
          /* eslint-enable no-await-in-loop */
        }

        this.clearMessage();
        this.hideRichLinkPreview();
      } catch (error) {
        const errorMessage =
          error?.message || this.$t('CONVERSATION.MESSAGE_ERROR');
        this.$store.dispatch('alerts/show', {
          message: errorMessage,
          type: 'error',
        });
      }
    },

    onRichLinkDismiss() {
      this.hideRichLinkPreview();
    },
  },
};
</script>

<template>
  <ReplyBoxBanner :message="message" :is-on-private-note="isOnPrivateNote" />
  <div ref="replyEditor" class="reply-box" :class="replyBoxClass">
    <ReplyTopPanel
      :mode="replyType"
      :conversation-id="conversationId"
      :is-reply-restricted="!canSendPublicReply"
      :disabled="
        (copilot.isActive.value && copilot.isButtonDisabled.value) ||
        showAudioRecorderEditor
      "
      :is-editor-disabled="isEditorDisabled"
      :is-message-length-reaching-threshold="isMessageLengthReachingThreshold"
      :characters-remaining="charactersRemaining"
      :editor-content="message"
      :has-content="hasMeaningfulEditorContent"
      :popout-reply-box="popOutReplyBox"
      @set-reply-mode="setReplyMode"
      @toggle-editor-size="toggleEditorSize"
      @toggle-copilot="copilot.toggleEditor"
      @execute-copilot-action="executeCopilotAction"
      @toggle-popout="togglePopout"
    />
    <ArticleSearchPopover
      v-if="showArticleSearchPopover && connectedPortalSlug"
      :selected-portal-slug="connectedPortalSlug"
      @insert="handleInsert"
      @close="onSearchPopoverClose"
    />
    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <div :key="copilot.editorTransitionKey.value" class="reply-box__top">
        <ReplyToMessage
          v-if="shouldShowReplyToMessage"
          :message="inReplyTo"
          @dismiss="resetReplyToMessage"
        />
        <AppleRichLinkPreview
          v-if="showRichLinkPreview"
          :url="richLinkPreviewUrl"
          :conversation="currentChat"
          :original-message="message"
          @send-as-text="onRichLinkSendAsText"
          @send-as-rich-link="onRichLinkSendAsRichLink"
          @dismiss="onRichLinkDismiss"
          @preview-loaded="richLinkCachedData = $event"
        />
        <TemplateSelector
          v-if="showMentions && hasSlashCommand"
          v-on-clickaway="hideMentions"
          class="normal-editor__template-box"
          :search-key="mentionSearchKey"
          @select="handleTemplateSelect"
        />
        <EmojiIconPicker
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          mode="emoji"
          class="emoji-dialog"
          :class="{
            'emoji-dialog--expanded': isOnExpandedLayout,
          }"
          @select="addIntoEditor($event.value)"
        />
        <ReplyEmailHead
          v-if="showReplyHead && isDefaultEditorMode"
          v-model:cc-emails="ccEmails"
          v-model:bcc-emails="bccEmails"
          v-model:to-emails="toEmails"
        />
        <AudioRecorder
          v-if="showAudioRecorderEditor"
          ref="audioRecorderInput"
          :audio-record-format="audioRecordFormat"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @record-error="onRecordError"
          @play="recordingAudioState = 'playing'"
          @pause="recordingAudioState = 'paused'"
        />
        <CopilotEditorSection
          v-if="copilot.isActive.value && !showAudioRecorderEditor"
          :show-copilot-editor="copilot.showEditor.value"
          :is-generating-content="copilot.isGenerating.value"
          :generated-content="copilot.generatedContent.value"
          :placeholder="$t('CONVERSATION.FOOTER.COPILOT_MSG_INPUT')"
          @focus="onFocus"
          @blur="onBlur"
          @clear-selection="clearEditorSelection"
          @close="copilot.showEditor.value = false"
          @content-ready="copilot.setContentReady"
          @send="copilot.sendFollowUp"
        />
        <WootMessageEditor
          v-else-if="!showAudioRecorderEditor"
          ref="messageEditor"
          v-model="message"
          :conversation-id="conversationId"
          :editor-id="editorStateId"
          class="input popover-prosemirror-menu"
          :is-private="isOnPrivateNote"
          :placeholder="messagePlaceHolder"
          :update-selection-with="updateEditorSelectionWith"
          :min-height="4"
          :disabled="isEditorDisabled"
          :enable-macros="isMacrosEnabled"
          enable-variables
          :variables="messageVariables"
          :signature="messageSignature"
          allow-signature
          :channel-type="channelType"
          :medium="inbox.medium"
          @typing-off="onTypingOff"
          @typing-on="onTypingOn"
          @focus="onFocus"
          @blur="onBlur"
          @toggle-user-mention="toggleUserMention"
          @toggle-canned-menu="toggleCannedMenu"
          @toggle-variables-menu="toggleVariablesMenu"
          @toggle-macros-menu="toggleMacrosMenu"
          @execute-macro="onExecuteMacro"
          @clear-selection="clearEditorSelection"
          @execute-copilot-action="executeCopilotAction"
        />

        <QuotedEmailPreview
          v-if="shouldShowQuotedPreview && isDefaultEditorMode"
          :quoted-email-text="quotedEmailText"
          :preview-text="quotedEmailPreviewText"
          class="mb-2"
          @toggle="toggleQuotedReply"
        />

        <div
          v-if="hasAttachments && isDefaultEditorMode"
          class="bg-transparent py-0 mb-2"
          @paste="onPaste"
        >
          <AttachmentPreview
            class="mt-2"
            :attachments="attachedFiles"
            @remove-attachment="removeAttachment"
          />
        </div>
        <MessageSignatureMissingAlert
          v-if="
            isSignatureEnabledForInbox &&
            !isSignatureAvailable &&
            isDefaultEditorMode
          "
          class="mb-2"
        />
      </div>
    </Transition>

    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <CopilotReplyBottomPanel
        v-if="copilot.isActive.value"
        key="copilot-bottom-panel"
        :is-generating-content="copilot.isButtonDisabled.value"
        @submit="onSubmitCopilotReply"
        @cancel="copilot.reset"
      />
      <ReplyBottomPanel
        v-else
        key="reply-bottom-panel"
        :conversation-id="conversationId"
        :enable-multiple-file-upload="enableMultipleFileUpload"
        :enable-whats-app-templates="showWhatsappTemplates"
        :enable-content-templates="showContentTemplates"
        :inbox="inbox"
        :is-on-private-note="isOnPrivateNote"
        :is-recording-audio="isRecordingAudio"
        :is-send-disabled="isReplyButtonDisabled"
        :is-note="isPrivate"
        :is-editor-disabled="isEditorDisabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"
        :conversation-type="conversationType"
        :recording-audio-duration-text="recordingAudioDurationText"
        :recording-audio-state="recordingAudioState"
        :send-button-text="replyButtonLabel"
        :show-audio-recorder="showAudioRecorder"
        :show-emoji-picker="showEmojiPicker"
        :show-file-upload="showFileUpload"
        :show-quoted-reply-toggle="shouldShowQuotedReplyToggle"
        :quoted-reply-enabled="quotedReplyPreference"
        :toggle-audio-recorder-play-pause="toggleAudioRecorderPlayPause"
        :toggle-audio-recorder="toggleAudioRecorder"
        :toggle-emoji-picker="toggleEmojiPicker"
        :message="message"
        :portal-slug="connectedPortalSlug"
        :new-conversation-modal-active="newConversationModalActive"
        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
        @send-apple-message="sendAppleMessage"
        @replace-text="replaceText"
      />
    </Transition>

    <WhatsappTemplates
      :inbox-id="inbox.id"
      :show="showWhatsAppTemplatesModal"
      :send-rendered-content="isAPIInbox"
      @close="hideWhatsappTemplatesModal"
      @on-send="onSendWhatsAppReply"
      @cancel="hideWhatsappTemplatesModal"
    />

    <ContentTemplates
      :inbox-id="inbox.id"
      :show="showContentTemplatesModal"
      @close="hideContentTemplatesModal"
      @on-send="onSendContentTemplateReply"
      @cancel="hideContentTemplatesModal"
    />

    <ConversationResolveAttributesModal
      ref="resolveAttributesModal"
      @submit="macroExecution.submitPendingAttributes"
      @close="macroExecution.dismissPendingAttributes"
    />

    <woot-confirm-modal
      ref="confirmDialog"
      :title="$t('CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.TITLE')"
      :description="undefinedVariableMessage"
    />
  </div>
</template>

<style lang="scss" scoped>
.send-button {
  @apply mb-0;
}

.reply-box {
  @apply relative mb-2 mx-2 border border-n-weak rounded-xl bg-n-solid-1;

  &.is-private {
    @apply bg-n-solid-amber dark:border-n-amber-3/10 border-n-amber-12/5;
  }
}

.send-button {
  @apply mb-0;
}

.reply-box__top {
  @apply relative py-0 px-3 -mt-px;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

.emoji-dialog--expanded {
  @apply left-[unset] bottom-0 absolute z-[100];

  &::before {
    transform: rotate(0deg);
    @apply ltr:left-1 rtl:right-1 -bottom-2;
  }
}

.normal-editor__template-box {
  width: calc(100% - 2 * 1rem);
  left: 1rem;
  position: absolute;
  bottom: 100%;
  z-index: 100;
  @apply bg-white dark:bg-n-slate-1;
  @apply border border-n-slate-4 dark:border-n-slate-6;
  border-radius: 8px;
  @apply shadow-lg dark:shadow-2xl;
  margin-bottom: 8px;
  max-height: 400px;
  overflow-y: auto;
}
</style>
