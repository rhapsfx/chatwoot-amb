<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const jsonError = ref('');

const attributesJson = computed({
  get: () => {
    const attrs = props.modelValue.attributes || {};
    try {
      return JSON.stringify(attrs, null, 2);
    } catch (e) {
      return '{}';
    }
  },
  set: value => {
    try {
      const parsed = JSON.parse(value);
      jsonError.value = '';
      emit('update:modelValue', { ...props.modelValue, attributes: parsed });
    } catch (e) {
      jsonError.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.JSON_ERROR'
      );
    }
  },
});

const formatJson = () => {
  try {
    const parsed = JSON.parse(attributesJson.value);
    attributesJson.value = JSON.stringify(parsed, null, 2);
    jsonError.value = '';
  } catch (e) {
    jsonError.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.JSON_ERROR'
    );
  }
};
</script>

<template>
  <div class="space-y-4">
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-n-slate-12">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.ATTRIBUTES'
            )
          }}
          *
        </label>
        <button
          class="px-3 py-1 text-xs text-n-blue-8 hover:bg-n-blue-2 rounded transition-colors"
          @click="formatJson"
        >
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.FORMAT_JSON'
            )
          }}
        </button>
      </div>

      <textarea
        v-model="attributesJson"
        rows="8"
        class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
        :class="
          jsonError
            ? 'border-red-500 focus:ring-red-500'
            : 'border-n-weak focus:ring-n-blue-8'
        "
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.ATTRIBUTES_PLACEHOLDER'
          )
        "
      />

      <p v-if="jsonError" class="mt-1 text-xs text-red-600">
        {{ jsonError }}
      </p>
      <p v-else class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.ATTRIBUTES_HELP'
          )
        }}
      </p>

      <!-- Example Section -->
      <div class="mt-3 p-3 bg-n-slate-2 border border-n-weak rounded-lg">
        <p class="text-xs font-medium text-n-slate-12 mb-1">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.UPDATE_ATTRIBUTES.PARAMETERS.EXAMPLE'
            )
          }}
        </p>
        <pre class="text-xs text-n-slate-11 font-mono overflow-x-auto">
{
  "priority": "high",
  "department": "sales",
  "lead_score": 85
}</pre>
      </div>
    </div>
  </div>
</template>
