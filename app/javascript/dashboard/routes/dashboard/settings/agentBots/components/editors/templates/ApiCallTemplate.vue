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

const headersError = ref('');
const bodyError = ref('');

// URL
const url = computed({
  get: () => props.modelValue.url || '',
  set: value => emit('update:modelValue', { ...props.modelValue, url: value }),
});

// HTTP Method
const method = computed({
  get: () => props.modelValue.method || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, method: value }),
});

// Headers (JSON)
const headersJson = computed({
  get: () => {
    const headers = props.modelValue.headers || {};
    try {
      return JSON.stringify(headers, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      headersError.value = '';
      emit('update:modelValue', { ...props.modelValue, headers: parsed });
    } catch (e) {
      headersError.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.JSON_ERROR'
      );
    }
  },
});

// Body (JSON)
const bodyJson = computed({
  get: () => {
    const body = props.modelValue.body || {};
    try {
      return JSON.stringify(body, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      bodyError.value = '';
      emit('update:modelValue', { ...props.modelValue, body: parsed });
    } catch (e) {
      bodyError.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.JSON_ERROR'
      );
    }
  },
});

// Store response in
const storeResponseIn = computed({
  get: () => props.modelValue.store_response_in || '',
  set: value =>
    emit('update:modelValue', {
      ...props.modelValue,
      store_response_in: value,
    }),
});

// Format JSON for headers
const formatHeaders = () => {
  try {
    const parsed = JSON.parse(headersJson.value);
    headersJson.value = JSON.stringify(parsed, null, 2);
    headersError.value = '';
  } catch (e) {
    headersError.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.JSON_ERROR'
    );
  }
};

// Format JSON for body
const formatBody = () => {
  try {
    const parsed = JSON.parse(bodyJson.value);
    bodyJson.value = JSON.stringify(parsed, null, 2);
    bodyError.value = '';
  } catch (e) {
    bodyError.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.JSON_ERROR'
    );
  }
};
</script>

<template>
  <div class="space-y-4">
    <!-- URL -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.URL'
          )
        }}
        *
      </label>
      <input
        v-model="url"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.URL_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- HTTP Method -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.METHOD'
          )
        }}
        *
      </label>
      <select
        v-model="method"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
      >
        <option value="">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.SELECT_METHOD'
            )
          }}
        </option>
        <option value="GET">GET</option>
        <option value="POST">POST</option>
        <option value="PUT">PUT</option>
        <option value="PATCH">PATCH</option>
        <option value="DELETE">DELETE</option>
      </select>
    </div>

    <!-- Headers (JSON) -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.HEADERS'
            )
          }}
        </label>
        <button
          class="px-3 py-1 text-xs text-n-blue-8 hover:bg-n-blue-2 rounded transition-colors"
          @click="formatHeaders"
        >
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.FORMAT_JSON'
            )
          }}
        </button>
      </div>

      <textarea
        v-model="headersJson"
        rows="4"
        class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
        :class="
          headersError
            ? 'border-red-500 focus:ring-red-500'
            : 'border-n-weak focus:ring-n-blue-8'
        "
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.HEADERS_PLACEHOLDER'
          )
        "
      />

      <p v-if="headersError" class="mt-1 text-xs text-red-600">
        {{ headersError }}
      </p>
      <p v-else class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.HEADERS_HELP'
          )
        }}
      </p>
    </div>

    <!-- Body (JSON) - Only for POST/PUT/PATCH -->
    <div v-if="['POST', 'PUT', 'PATCH'].includes(method)">
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.BODY'
            )
          }}
        </label>
        <button
          class="px-3 py-1 text-xs text-n-blue-8 hover:bg-n-blue-2 rounded transition-colors"
          @click="formatBody"
        >
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.FORMAT_JSON'
            )
          }}
        </button>
      </div>

      <textarea
        v-model="bodyJson"
        rows="4"
        class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
        :class="
          bodyError
            ? 'border-red-500 focus:ring-red-500'
            : 'border-n-weak focus:ring-n-blue-8'
        "
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.BODY_PLACEHOLDER'
          )
        "
      />

      <p v-if="bodyError" class="mt-1 text-xs text-red-600">
        {{ bodyError }}
      </p>
      <p v-else class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.BODY_HELP'
          )
        }}
      </p>
    </div>

    <!-- Store Response In -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.STORE_RESPONSE_IN'
          )
        }}
      </label>
      <input
        v-model="storeResponseIn"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.STORE_RESPONSE_IN_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.STORE_RESPONSE_IN_HELP'
          )
        }}
      </p>
    </div>

    <!-- Example Section -->
    <div class="p-4 bg-n-slate-2 border border-n-weak rounded-lg">
      <p class="text-xs font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.API_CALL.PARAMETERS.EXAMPLE'
          )
        }}
      </p>
      <pre class="text-xs text-n-slate-11 font-mono overflow-x-auto">
{
  "Authorization": "Bearer abc123",
  "Content-Type": "application/json"
}</pre>
    </div>
  </div>
</template>
