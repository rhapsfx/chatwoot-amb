<script setup>
import { computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  payload: { type: Object, default: null },
  status: { type: String, default: 'sent' },
  contentAttributes: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['close']);

const show = defineModel('show', { type: Boolean, default: false });

const isFailed = computed(() => props.status === 'failed');

const errorMessage = computed(() => {
  return (
    props.contentAttributes?.externalError ||
    props.contentAttributes?.external_error
  );
});

// Extract the actual payload from the wrapped structure
const actualPayload = computed(() => {
  // The appleMspPayload prop from backend has structure:
  // { payload: {...actual Apple MSP payload...}, debug: {...} }
  // We need to extract the inner payload for display
  if (props.payload) {
    // Check if it's wrapped (from database)
    if (props.payload.payload) {
      return props.payload.payload;
    }
    // Otherwise return as-is (direct payload)
    return props.payload;
  }
  return null;
});

// Extract debug info from the wrapped payload if present
const actualDebugInfo = computed(() => {
  // Extract debug info from the wrapped payload if present
  if (props.payload?.debug) {
    return props.payload.debug;
  }

  // Otherwise create basic debug info
  const info = {
    status: props.status,
    timestamp: new Date().toISOString(),
  };

  if (errorMessage.value) {
    info.error = errorMessage.value;
  }

  return info;
});

const debugInfo = computed(() => actualDebugInfo.value);

const formattedPayload = computed(() => {
  // For sent messages, show the actual payload sent to Apple
  if (actualPayload.value) {
    try {
      // The actualPayload is the complete Apple MSP payload
      return JSON.stringify(actualPayload.value, null, 2);
    } catch (e) {
      return 'Error formatting payload';
    }
  }

  // For received messages, show content attributes
  if (
    props.contentAttributes &&
    Object.keys(props.contentAttributes).length > 0
  ) {
    try {
      return JSON.stringify(props.contentAttributes, null, 2);
    } catch (e) {
      return 'Error formatting content attributes';
    }
  }

  return 'No payload data available';
});

const payloadLabel = computed(() => {
  if (actualPayload.value) {
    return 'Request Payload (Sent to Apple MSP Gateway)';
  }
  return 'Received Payload (From Apple)';
});

const payloadDescription = computed(() => {
  if (actualPayload.value) {
    return 'This is the exact JSON structure sent to mspgw.push.apple.com/v1. Fields v, id, sourceId, destinationId are auto-populated by the system.';
  }
  return 'This is the payload received from Apple Messages for Business.';
});

const formattedDebugInfo = computed(() => {
  try {
    return JSON.stringify(debugInfo.value, null, 2);
  } catch (e) {
    return 'Error formatting debug info';
  }
});

const copyToClipboard = async () => {
  try {
    // For sent messages: copy the actual payload sent to Apple (unwrapped)
    // For received messages: copy the content attributes
    const dataToCopy = actualPayload.value || props.contentAttributes;

    const fullData = {
      debug: actualDebugInfo.value,
      payload: dataToCopy,
    };

    await navigator.clipboard.writeText(JSON.stringify(fullData, null, 2));
    useAlert('Payload copied to clipboard');
  } catch (err) {
    useAlert('Failed to copy payload');
  }
};

// Recursively remove base64 image data from objects
const stripBase64Data = obj => {
  if (obj === null || obj === undefined) return obj;

  if (Array.isArray(obj)) {
    return obj.map(item => stripBase64Data(item));
  }

  if (typeof obj === 'object') {
    const cleaned = {};
    Object.keys(obj).forEach(key => {
      const value = obj[key];
      // Remove 'data' field if it appears to be base64 (starts with / or contains base64 indicators)
      if (
        key === 'data' &&
        typeof value === 'string' &&
        (value.startsWith('/') ||
          value.includes('base64') ||
          value.length > 100)
      ) {
        cleaned[key] = '[BASE64_DATA_REMOVED]';
      } else {
        cleaned[key] = stripBase64Data(value);
      }
    });
    return cleaned;
  }

  return obj;
};

const copyPayloadOnly = async () => {
  try {
    // Copy ONLY the interactiveData field for use in Custom Payload textarea
    const payload = actualPayload.value || props.contentAttributes;

    if (!payload) {
      useAlert('No payload to copy');
      return;
    }

    // Extract just the interactiveData (the part needed for custom payload)
    const interactiveData = payload.interactiveData || payload.interactive_data;

    if (interactiveData) {
      // CRITICAL: Strip base64 image data to keep payload manageable
      // Images will be automatically fetched from storage when sending
      const strippedInteractiveData = stripBase64Data(interactiveData);

      // Copy only the interactiveData object wrapped in root object
      const customPayloadFormat = {
        interactiveData: strippedInteractiveData,
      };
      await navigator.clipboard.writeText(
        JSON.stringify(customPayloadFormat, null, 2)
      );
      useAlert(
        'Interactive data copied (images removed - will auto-fetch on send)'
      );
    } else {
      // For non-interactive messages, copy the whole payload
      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
      useAlert('Payload copied');
    }
  } catch (err) {
    useAlert('Failed to copy payload');
  }
};

const copyToClipboardLight = async () => {
  try {
    // For sent messages: copy the actual payload sent to Apple (unwrapped, without base64)
    // For received messages: copy the content attributes (without base64)
    const dataToCopy = actualPayload.value || props.contentAttributes;

    const lightData = {
      debug: actualDebugInfo.value,
      payload: stripBase64Data(dataToCopy),
    };

    await navigator.clipboard.writeText(JSON.stringify(lightData, null, 2));
    useAlert('Light payload copied (base64 data removed)');
  } catch (err) {
    useAlert('Failed to copy light payload');
  }
};

const closeModal = () => {
  emit('close');
};
</script>

<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<template>
  <Modal
    v-model:show="show"
    :on-close="closeModal"
    :show-close-button="false"
    size="large"
  >
    <div class="flex flex-col h-full max-h-[80vh]">
      <div
        class="flex items-start justify-between p-4 border-b border-n-weak gap-4"
      >
        <div class="flex-1 min-w-0">
          <h3 class="text-base font-semibold text-n-slate-12 mb-1">
            Apple Messages Payload
          </h3>
          <p class="text-xs text-n-slate-11">
            {{
              props.payload
                ? 'JSON payload sent to mspgw.apple.com'
                : 'JSON payload received from Apple'
            }}
          </p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <button
            class="px-3 py-1.5 text-xs font-medium text-white bg-n-blue-9 hover:bg-n-blue-10 rounded-md transition-colors flex items-center gap-1.5"
            title="Copy interactiveData only (for Custom Payload textarea)"
            @click="copyPayloadOnly"
          >
            <fluent-icon icon="copy" size="14" />
            Copy for Custom Payload
          </button>
          <button
            class="px-3 py-1.5 text-xs font-medium text-n-slate-12 bg-n-alpha-2 hover:bg-n-alpha-3 rounded-md transition-colors flex items-center gap-1.5"
            title="Copy full payload with debug info and all image data"
            @click="copyToClipboard"
          >
            <fluent-icon icon="copy" size="14" />
            Copy All
          </button>
          <button
            class="px-3 py-1.5 text-xs font-medium text-n-slate-11 bg-n-alpha-1 hover:bg-n-alpha-2 rounded-md transition-colors flex items-center gap-1.5 border border-n-weak"
            title="Copy payload without base64 image data (LLM-friendly)"
            @click="copyToClipboardLight"
          >
            <fluent-icon icon="copy" size="14" />
            Copy (Light)
          </button>
          <button
            class="p-1.5 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 rounded-md transition-colors"
            @click="closeModal"
          >
            <fluent-icon icon="dismiss" size="18" />
          </button>
        </div>
      </div>

      <div class="flex-1 overflow-auto p-4 bg-n-slate-1">
        <!-- Error Alert for Failed Messages -->
        <div
          v-if="isFailed"
          class="mb-4 p-3 bg-n-ruby-2 border border-n-ruby-6 rounded-md"
        >
          <div class="flex items-start gap-2">
            <fluent-icon
              icon="error-circle"
              size="16"
              class="text-n-ruby-11 mt-0.5 flex-shrink-0"
            />
            <div class="flex-1 min-w-0">
              <div class="text-sm font-semibold text-n-ruby-12 mb-1">
                Message Failed to Send
              </div>
              <div
                v-if="errorMessage"
                class="text-xs text-n-ruby-11 font-mono break-all"
              >
                {{ errorMessage }}
              </div>
            </div>
          </div>
        </div>

        <!-- Debug Information -->
        <div class="mb-4">
          <div class="flex items-center gap-2 mb-2">
            <fluent-icon icon="info" size="14" class="text-n-slate-11" />
            <h4 class="text-xs font-semibold text-n-slate-12">
              Debug Information
            </h4>
          </div>
          <pre
            class="p-3 bg-n-slate-2 rounded-md text-xs font-mono text-n-slate-12 overflow-x-auto border border-n-weak"
            >{{ formattedDebugInfo }}</pre
          >
        </div>

        <!-- Payload -->
        <div>
          <div class="flex items-start gap-2 mb-2">
            <fluent-icon icon="code" size="14" class="text-n-slate-11 mt-0.5" />
            <div class="flex-1 min-w-0">
              <h4 class="text-xs font-semibold text-n-slate-12">
                {{ payloadLabel }}
              </h4>
              <p class="text-xs text-n-slate-10 mt-0.5">
                {{ payloadDescription }}
              </p>
            </div>
          </div>
          <pre
            class="p-4 bg-n-slate-2 rounded-md text-xs font-mono text-n-slate-12 overflow-x-auto border border-n-weak leading-relaxed"
            >{{ formattedPayload }}</pre
          >
        </div>
      </div>
    </div>
  </Modal>
</template>
