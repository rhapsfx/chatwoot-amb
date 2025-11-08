<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';
import FileIcon from 'next/icon/FileIcon.vue';

const { attachments } = useMessageContext();

const { t } = useI18n();

const url = computed(() => {
  return attachments.value[0].dataUrl;
});

const fileName = computed(() => {
  // Use the file_name from attachment metadata if available
  if (attachments.value[0].fileName) {
    return attachments.value[0].fileName;
  }

  // Fallback to parsing URL if fileName not available
  if (url.value) {
    const filename = url.value.substring(url.value.lastIndexOf('/') + 1);
    // Remove query parameters (token, etc) from filename
    return filename.split('?')[0] || t('CONVERSATION.UNKNOWN_FILE_TYPE');
  }
  return t('CONVERSATION.UNKNOWN_FILE_TYPE');
});

const fileType = computed(() => {
  return fileName.value.split('.').pop();
});

const fileSize = computed(() => {
  const size = attachments.value[0].fileSize;
  if (!size) return '';

  // Format file size
  if (size < 1024) {
    return `${size} B`;
  }
  if (size < 1024 * 1024) {
    return `${(size / 1024).toFixed(1)} KB`;
  }
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
});

const displayContent = computed(() => {
  const name = decodeURI(fileName.value);
  const size = fileSize.value;
  return size ? `${name} (${size})` : name;
});
</script>

<template>
  <BaseAttachmentBubble
    icon="i-teenyicons-user-circle-solid"
    icon-bg-color="bg-n-alpha-3 dark:bg-n-alpha-white"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.FILE"
    :content="displayContent"
    :action="{
      href: url,
      label: $t('CONVERSATION.DOWNLOAD'),
    }"
  >
    <template #icon>
      <FileIcon :file-type="fileType" class="size-4" />
    </template>
  </BaseAttachmentBubble>
</template>
