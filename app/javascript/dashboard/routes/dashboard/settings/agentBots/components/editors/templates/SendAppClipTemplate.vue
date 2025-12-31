<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  // eslint-disable-next-line vue/no-unused-properties
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

// App Clip URL
const appClipUrl = computed({
  get: () => props.modelValue.app_clip_url || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, app_clip_url: value }),
});

// Title
const title = computed({
  get: () => props.modelValue.title || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, title: value }),
});

// Subtitle
const subtitle = computed({
  get: () => props.modelValue.subtitle || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, subtitle: value }),
});

// Image URL
const imageUrl = computed({
  get: () => props.modelValue.image_url || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, image_url: value }),
});

// Action Title
const actionTitle = computed({
  get: () => props.modelValue.action_title || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, action_title: value }),
});
</script>

<template>
  <div class="space-y-4">
    <!-- App Clip URL -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.APP_CLIP_URL'
          )
        }}
        *
      </label>
      <input
        v-model="appClipUrl"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.APP_CLIP_URL_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.APP_CLIP_URL_HELP'
          )
        }}
      </p>
    </div>

    <!-- Title -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t('AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.TITLE')
        }}
        *
      </label>
      <input
        v-model="title"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.TITLE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Subtitle (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.SUBTITLE'
          )
        }}
      </label>
      <input
        v-model="subtitle"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.SUBTITLE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Image URL (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.IMAGE_URL'
          )
        }}
      </label>
      <input
        v-model="imageUrl"
        type="url"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.IMAGE_URL_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.IMAGE_URL_HELP'
          )
        }}
      </p>
    </div>

    <!-- Action Title (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.ACTION_TITLE'
          )
        }}
      </label>
      <input
        v-model="actionTitle"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.ACTION_TITLE_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.ACTION_TITLE_HELP'
          )
        }}
      </p>
    </div>

    <!-- App Clip Info -->
    <div class="p-4 bg-green-50 border border-green-200 rounded-lg">
      <p class="text-sm font-medium text-green-900 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.INFO_TITLE'
          )
        }}
      </p>
      <p class="text-xs text-green-800">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.SEND_APP_CLIP.PARAMETERS.INFO_TEXT'
          )
        }}
      </p>
    </div>
  </div>
</template>
