<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  // eslint-disable-next-line vue/no-unused-properties
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const dataError = ref('');

// App ID (Bundle Identifier)
const appId = computed({
  get: () => props.modelValue.app_id || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, app_id: value }),
});

// App Name
const appName = computed({
  get: () => props.modelValue.app_name || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, app_name: value }),
});

// App Icon URL
const appIconUrl = computed({
  get: () => props.modelValue.app_icon_url || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, app_icon_url: value }),
});

// Launch URL
const launchUrl = computed({
  get: () => props.modelValue.launch_url || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, launch_url: value }),
});

// App Data (JSON)
const dataJson = computed({
  get: () => {
    const data = props.modelValue.data || {};
    try {
      return JSON.stringify(data, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      dataError.value = '';
      emit('update:modelValue', { ...props.modelValue, data: parsed });
    } catch (e) {
      dataError.value = t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.JSON_ERROR'
      );
    }
  },
});

// Format JSON for data
const formatData = () => {
  try {
    const parsed = JSON.parse(dataJson.value);
    dataJson.value = JSON.stringify(parsed, null, 2);
    dataError.value = '';
  } catch (e) {
    dataError.value = t(
      'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.JSON_ERROR'
    );
  }
};
</script>

<template>
  <div class="space-y-4">
    <!-- App ID (Bundle Identifier) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_ID'
          )
        }}
        *
      </label>
      <input
        v-model="appId"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_ID_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_ID_HELP'
          )
        }}
      </p>
    </div>

    <!-- App Name -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_NAME'
          )
        }}
        *
      </label>
      <input
        v-model="appName"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_NAME_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- App Icon URL (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_ICON_URL'
          )
        }}
      </label>
      <input
        v-model="appIconUrl"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.APP_ICON_URL_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Launch URL (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.LAUNCH_URL'
          )
        }}
      </label>
      <input
        v-model="launchUrl"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.LAUNCH_URL_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.LAUNCH_URL_HELP'
          )
        }}
      </p>
    </div>

    <!-- App Data (JSON, Optional) -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.DATA'
            )
          }}
        </label>
        <button
          class="px-3 py-1 text-xs text-n-blue-8 hover:bg-n-blue-2 rounded transition-colors"
          @click="formatData"
        >
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.FORMAT_JSON'
            )
          }}
        </button>
      </div>

      <textarea
        v-model="dataJson"
        rows="4"
        class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
        :class="
          dataError
            ? 'border-red-500 focus:ring-red-500'
            : 'border-n-weak focus:ring-n-blue-8'
        "
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.DATA_PLACEHOLDER'
          )
        "
      />

      <p v-if="dataError" class="mt-1 text-xs text-red-600">
        {{ dataError }}
      </p>
    </div>

    <!-- Known Apps Examples -->
    <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
      <p class="text-sm font-medium text-blue-900 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.KNOWN_APPS_TITLE'
          )
        }}
      </p>
      <ul class="text-xs text-blue-800 space-y-1">
        <li>
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.KNOWN_APPS.SHAZAM'
            )
          }}
        </li>
        <li>
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.KNOWN_APPS.APPLE_MUSIC'
            )
          }}
        </li>
        <li>
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_IMESSAGE_APP.PARAMETERS.KNOWN_APPS.PHOTOS'
            )
          }}
        </li>
      </ul>
    </div>
  </div>
</template>
