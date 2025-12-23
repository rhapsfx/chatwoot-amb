<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const message = computed({
  get: () => props.modelValue.message || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, message: value }),
});

const delaySeconds = computed({
  get: () => props.modelValue.delay_seconds ?? null,
  set: value =>
    emit('update:modelValue', { ...props.modelValue, delay_seconds: value }),
});
</script>

<template>
  <div class="space-y-4">
    <!-- Message Text -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.MESSAGE'
          )
        }}
        *
      </label>
      <textarea
        v-model="message"
        rows="4"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.MESSAGE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Delay (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_SECONDS'
          )
        }}
      </label>
      <input
        v-model.number="delaySeconds"
        type="number"
        min="0"
        step="0.5"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TEXT_MESSAGE.PARAMETERS.DELAY_HELP'
          )
        }}
      </p>
    </div>
  </div>
</template>
