<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import BaseBubble from './Base.vue';
import Button from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import { downloadFile } from '@chatwoot/utils';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const { t } = useI18n();

const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const { hasError, loadWithRetry } = useLoadWithRetry();

const showGallery = ref(false);
const isDownloading = ref(false);
const imageDataUrl = ref(null);
const isLoading = ref(true);

onMounted(() => {
  if (attachment.value?.dataUrl) {
    loadWithRetry(attachment.value.dataUrl);
  }
});

const downloadAttachment = async () => {
  const { fileType, dataUrl, extension } = attachment.value;
  try {
    isDownloading.value = true;
    await downloadFile({ url: dataUrl, type: fileType, extension });
  } catch (error) {
    useAlert(t('GALLERY_VIEW.ERROR_DOWNLOADING'));
  } finally {
    isDownloading.value = false;
  }
};

// Check if URL is from ngrok (Apple Messages for Business)
const isNgrokUrl = computed(() => {
  return (
    attachment.value?.dataUrl?.includes('.ngrok-free.app') ||
    attachment.value?.dataUrl?.includes('.ngrok.io')
  );
});

// Load image with proper headers to bypass ngrok browser warning
const loadImageWithHeaders = async url => {
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'ngrok-skip-browser-warning': 'true',
      'User-Agent': 'Chatwoot-Apple-Messages-For-Business',
      Accept: 'image/*,*/*;q=0.8',
    },
    mode: 'cors',
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const blob = await response.blob();
  return URL.createObjectURL(blob);
};

// Load image on mount - use upstream's loadWithRetry for non-ngrok, custom logic for ngrok
onMounted(async () => {
  if (!attachment.value?.dataUrl) {
    hasError.value = true;
    return;
  }

  try {
    if (isNgrokUrl.value) {
      // For ngrok URLs, use fetch with proper headers
      imageDataUrl.value = await loadImageWithHeaders(attachment.value.dataUrl);
    } else {
      // For regular URLs, use upstream's loadWithRetry
      await loadWithRetry(attachment.value.dataUrl);
      imageDataUrl.value = attachment.value.dataUrl;
    }
    isLoading.value = false;
  } catch (error) {
    hasError.value = true;
    isLoading.value = false;
  }
});

const handleImageError = () => {
  hasError.value = true;
};
</script>

<template>
  <BaseBubble
    class="overflow-hidden p-3"
    data-bubble-name="image"
    @click="showGallery = true"
  >
    <div v-if="hasError" class="flex items-center gap-1 text-center rounded-lg">
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      <p class="mb-0 text-n-slate-11">
        {{ $t('COMPONENTS.MEDIA.IMAGE_UNAVAILABLE') }}
      </p>
    </div>
    <div
      v-else-if="isLoading"
      class="flex items-center justify-center p-8 rounded-lg"
    >
      <Icon icon="i-lucide-loader-2" class="animate-spin text-n-slate-11" />
    </div>
    <div v-else class="relative group rounded-lg overflow-hidden">
      <img
        class="skip-context-menu"
        :src="imageDataUrl"
        :width="attachment.width"
        :height="attachment.height"
      />
      <div
        class="inset-0 p-2 pointer-events-none absolute bg-gradient-to-tl from-n-slate-12/30 dark:from-n-slate-1/50 via-transparent to-transparent hidden group-hover:flex"
      />
      <div class="absolute right-2 bottom-2 hidden group-hover:flex gap-2">
        <Button xs solid slate icon="i-lucide-expand" class="opacity-60" />
        <Button
          xs
          solid
          slate
          icon="i-lucide-download"
          class="opacity-60"
          :is-loading="isDownloading"
          :disabled="isDownloading"
          @click.stop="downloadAttachment"
        />
      </div>
    </div>
  </BaseBubble>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleImageError"
    @close="() => (showGallery = false)"
  />
</template>
