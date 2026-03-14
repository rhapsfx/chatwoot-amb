<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const { contentAttributes } = useMessageContext();

const invitationTemplateId = computed(
  () => contentAttributes.value?.invitation_template_id || ''
);

const referenceId = computed(() => contentAttributes.value?.reference_id || '');

const locale = computed(() => contentAttributes.value?.locale || 'en-US');

const isOptedOut = computed(() => !!contentAttributes.value?.opted_out);
</script>

<template>
  <BaseBubble>
    <div class="min-w-[200px] max-w-xs">
      <!-- Header row -->
      <div class="flex items-center gap-2 mb-2">
        <span
          class="flex items-center justify-center w-6 h-6 rounded-full bg-n-blue-3"
        >
          <i class="i-lucide-bell text-n-blue-9 text-xs" />
        </span>
        <span
          class="text-xs font-semibold text-n-blue-10 uppercase tracking-wide"
        >
          {{ t('APPLE_MESSAGES.INVITATION.CAMPAIGN_TITLE') }}
        </span>
        <span
          v-if="isOptedOut"
          class="ml-auto inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-red-100 text-red-700"
        >
          {{ t('APPLE_MESSAGES.INVITATION.OPTED_OUT_BADGE') }}
        </span>
      </div>

      <!-- Template ID -->
      <p
        v-if="invitationTemplateId"
        class="text-sm font-medium text-n-slate-12 font-mono break-all leading-snug"
      >
        {{ invitationTemplateId }}
      </p>
      <p v-else class="text-sm text-n-slate-9 italic">
        {{ t('APPLE_MESSAGES.INVITATION.TEMPLATE_LABEL') }}
      </p>

      <!-- Reference ID + locale row -->
      <div class="flex items-center gap-3 mt-2">
        <div
          v-if="referenceId"
          class="flex items-center gap-1 text-xs text-n-slate-10"
        >
          <i class="i-lucide-hash text-xs" />
          <span>{{ referenceId }}</span>
        </div>
        <div class="flex items-center gap-1 text-xs text-n-slate-10">
          <i class="i-lucide-globe text-xs" />
          <span>{{ locale }}</span>
        </div>
      </div>

      <!-- Opted Out Notice -->
      <div
        v-if="isOptedOut"
        class="mt-2 p-2 bg-red-50 rounded text-xs text-red-600"
      >
        {{ t('APPLE_MESSAGES.INVITATION.USER_LEFT') }}
      </div>
    </div>
  </BaseBubble>
</template>
