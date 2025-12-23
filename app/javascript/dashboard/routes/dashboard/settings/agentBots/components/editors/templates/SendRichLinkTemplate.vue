<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const url = computed({
  get: () => props.modelValue.url || '',
  set: value => emit('update:modelValue', { ...props.modelValue, url: value }),
});

const title = computed({
  get: () => props.modelValue.title || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, title: value }),
});

const subtitle = computed({
  get: () => props.modelValue.subtitle || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, subtitle: value }),
});

const imageUrl = computed({
  get: () => props.modelValue.image_url || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, image_url: value }),
});
</script>

<template>
  <div class="space-y-4">
    <!-- URL -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.URL'
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
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.URL_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.URL_HELP'
          )
        }}
      </p>
    </div>

    <!-- Title -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.TITLE'
          )
        }}
        *
      </label>
      <input
        v-model="title"
        type="text"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.TITLE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Subtitle (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.SUBTITLE'
          )
        }}
      </label>
      <input
        v-model="subtitle"
        type="text"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.SUBTITLE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Image URL (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.IMAGE_URL'
          )
        }}
      </label>
      <input
        v-model="imageUrl"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.IMAGE_URL_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_RICH_LINK.PARAMETERS.IMAGE_URL_HELP'
          )
        }}
      </p>
    </div>
  </div>
</template>
