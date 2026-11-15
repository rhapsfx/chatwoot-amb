<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import TemplatesAPI from 'dashboard/api/templates';

const props = defineProps({
  templateId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['attachmentsUpdated']);

const { t } = useI18n();

// State
const attachments = ref([]);
const uploading = ref(false);
const loading = ref(false);
const isDraggingOver = ref(false);

// Constants
const MAX_FILES = 10;
const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100 MB
const ALLOWED_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/heic',
  'image/webp',
  'video/mp4',
  'video/quicktime',
  'video/mpeg',
  'audio/mpeg',
  'audio/mp4',
  'audio/wav',
  'audio/aac',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
  'application/zip',
  'application/x-7z-compressed',
  'application/vnd.rar',
  'model/vnd.usdz+zip', // USDZ 3D models
  'model/usd', // USD 3D models
];

// Computed
const canAddMore = computed(() => attachments.value.length < MAX_FILES);

const formatFileSize = bytes => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / k ** i).toFixed(2))} ${sizes[i]}`;
};

const getFileIcon = file => {
  const contentType = file.contentType || file.type || file.mimeType;
  if (contentType?.startsWith('image/')) return 'i-lucide-image';
  if (contentType?.startsWith('video/')) return 'i-lucide-video';
  if (contentType?.startsWith('audio/')) return 'i-lucide-music';
  if (contentType?.startsWith('model/')) return 'i-lucide-box'; // 3D models
  if (contentType?.includes('pdf')) return 'i-lucide-file-text';
  if (contentType?.includes('word') || contentType?.includes('document'))
    return 'i-lucide-file-text';
  if (contentType?.includes('excel') || contentType?.includes('sheet'))
    return 'i-lucide-table';
  if (
    contentType?.includes('powerpoint') ||
    contentType?.includes('presentation')
  )
    return 'i-lucide-presentation';
  if (
    contentType?.includes('zip') ||
    contentType?.includes('compressed') ||
    contentType?.includes('rar')
  )
    return 'i-lucide-archive';
  if (contentType?.includes('text') || contentType?.includes('csv'))
    return 'i-lucide-file-text';
  return 'i-lucide-file';
};

// Methods
const fetchAttachments = async () => {
  loading.value = true;
  try {
    const response = await TemplatesAPI.getAttachments(props.templateId);
    // Extract attachments from template response (camelCase from backend)
    attachments.value = response.data.attachmentsSummary || [];
    emit('attachmentsUpdated', attachments.value);
  } catch (error) {
    // Template might not have attachments yet, which is fine
    attachments.value = [];
  } finally {
    loading.value = false;
  }
};

const validateFile = file => {
  if (file.size > MAX_FILE_SIZE) {
    useAlert(
      t('TEMPLATE_ATTACHMENTS.ERRORS.FILE_TOO_LARGE', {
        name: file.name,
        max: '100 MB',
      })
    );
    return false;
  }

  if (!ALLOWED_TYPES.includes(file.type)) {
    useAlert(
      t('TEMPLATE_ATTACHMENTS.ERRORS.INVALID_FILE_TYPE', {
        name: file.name,
      })
    );
    return false;
  }

  return true;
};

const handleFiles = async files => {
  const validFiles = Array.from(files).filter(validateFile);

  if (attachments.value.length + validFiles.length > MAX_FILES) {
    useAlert(
      t('TEMPLATE_ATTACHMENTS.ERRORS.TOO_MANY_FILES', { max: MAX_FILES })
    );
    return;
  }

  uploading.value = true;

  try {
    const startIndex = attachments.value.length;
    await Promise.all(
      validFiles.map((file, i) =>
        TemplatesAPI.uploadAttachment(props.templateId, file, startIndex + i)
      )
    );

    // Refetch all attachments from server after upload
    await fetchAttachments();

    useAlert(t('TEMPLATE_ATTACHMENTS.SUCCESS.FILES_UPLOADED'));
  } catch {
    useAlert(t('TEMPLATE_ATTACHMENTS.ERRORS.UPLOAD_FAILED'));
  } finally {
    uploading.value = false;
  }
};

const removeAttachment = async attachment => {
  try {
    await TemplatesAPI.deleteAttachment(props.templateId, attachment.id);

    const index = attachments.value.findIndex(a => a.id === attachment.id);
    if (index !== -1) {
      attachments.value.splice(index, 1);

      // Reorder remaining attachments
      const attachmentIds = attachments.value.map(a => a.id);
      if (attachmentIds.length > 0) {
        await TemplatesAPI.reorderAttachments(props.templateId, attachmentIds);
      }

      useAlert(t('TEMPLATE_ATTACHMENTS.SUCCESS.FILE_REMOVED'));
      emit('attachmentsUpdated', attachments.value);
    }
  } catch (error) {
    useAlert(t('TEMPLATE_ATTACHMENTS.ERRORS.REMOVE_FAILED'));
  }
};

const handleDrop = e => {
  e.preventDefault();
  isDraggingOver.value = false;

  const files = e.dataTransfer.files;
  if (files.length > 0) {
    handleFiles(files);
  }
};

const handleDragOver = e => {
  e.preventDefault();
  isDraggingOver.value = true;
};

const handleDragLeave = () => {
  isDraggingOver.value = false;
};

const handleFileInput = e => {
  const files = e.target.files;
  if (files.length > 0) {
    handleFiles(files);
  }
  // Reset input so same file can be selected again
  e.target.value = '';
};

const triggerFileInput = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.multiple = true;
  input.accept = ALLOWED_TYPES.join(',');
  input.onchange = handleFileInput;
  input.click();
};

const handleReorder = async () => {
  try {
    const attachmentIds = attachments.value.map(a => a.id);
    await TemplatesAPI.reorderAttachments(props.templateId, attachmentIds);
    emit('attachmentsUpdated', attachments.value);
  } catch (error) {
    useAlert(t('TEMPLATE_ATTACHMENTS.ERRORS.REORDER_FAILED'));
  }
};

onMounted(() => {
  fetchAttachments();
});
</script>

<template>
  <div class="space-y-4">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <woot-loading-state :message="t('TEMPLATES.LOADING')" />
    </div>

    <template v-else>
      <!-- Header -->
      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ t('TEMPLATE_ATTACHMENTS.LABEL') }}
        </label>
        <p class="text-sm text-n-slate-11 mb-3">
          {{ t('TEMPLATE_ATTACHMENTS.DESCRIPTION', { max: MAX_FILES }) }}
        </p>
      </div>

      <!-- Drag-and-Drop Upload Area -->
      <div
        v-if="canAddMore"
        class="border-2 border-dashed rounded-lg p-8 text-center transition-colors cursor-pointer"
        :class="[
          isDraggingOver
            ? 'border-n-blue-7 bg-n-blue-1'
            : 'border-n-slate-7 hover:border-n-blue-7 hover:bg-n-slate-1',
        ]"
        @drop="handleDrop"
        @dragover="handleDragOver"
        @dragleave="handleDragLeave"
        @click="triggerFileInput"
      >
        <i
          class="text-4xl mb-3 text-n-slate-11"
          :class="isDraggingOver ? 'i-lucide-download' : 'i-lucide-upload'"
        />
        <div class="text-sm text-n-slate-12 font-medium mb-1">
          {{
            isDraggingOver
              ? t('TEMPLATE_ATTACHMENTS.DROP_HERE')
              : t('TEMPLATE_ATTACHMENTS.DRAG_DROP')
          }}
        </div>
        <div class="text-xs text-n-slate-11">
          {{ t('TEMPLATE_ATTACHMENTS.FILE_TYPES') }}
        </div>
        <div class="text-xs text-n-slate-10 mt-1">
          {{ t('TEMPLATE_ATTACHMENTS.MAX_SIZE', { size: '100 MB' }) }}
        </div>
      </div>

      <!-- File List -->
      <div v-if="attachments.length > 0" class="space-y-2">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{
              t('TEMPLATE_ATTACHMENTS.FILES_LABEL', {
                count: attachments.length,
                max: MAX_FILES,
              })
            }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('TEMPLATE_ATTACHMENTS.DRAG_TO_REORDER') }}
          </span>
        </div>

        <Draggable
          v-model="attachments"
          animation="200"
          item-key="id"
          ghost-class="opacity-50"
          handle=".drag-handle"
          @end="handleReorder"
        >
          <template #item="{ element: attachment }">
            <div
              class="flex items-center gap-3 p-3 bg-white dark:bg-n-slate-2 border border-n-slate-7 rounded-lg hover:border-n-blue-7 transition-colors"
            >
              <!-- Drag Handle -->
              <div
                class="drag-handle flex-shrink-0 cursor-move text-n-slate-11 hover:text-n-slate-12"
              >
                <i class="i-lucide-grip-vertical text-lg" />
              </div>

              <!-- Preview / Icon -->
              <div class="flex-shrink-0">
                <div
                  v-if="attachment.preview"
                  class="w-12 h-12 rounded overflow-hidden bg-n-slate-3"
                >
                  <img
                    :src="attachment.preview"
                    :alt="attachment.name"
                    class="w-full h-full object-cover"
                  />
                </div>
                <div
                  v-else
                  class="w-12 h-12 rounded bg-n-slate-3 flex items-center justify-center"
                >
                  <i
                    :class="getFileIcon(attachment)"
                    class="text-xl text-n-slate-11"
                  />
                </div>
              </div>

              <!-- File Info -->
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-n-slate-12 truncate">
                  {{ attachment.name }}
                </div>
                <div class="text-xs text-n-slate-11">
                  {{ formatFileSize(attachment.size) }}
                </div>
              </div>

              <!-- Delete Button -->
              <Button
                icon="i-lucide-trash-2"
                ruby
                xs
                faded
                @click="removeAttachment(attachment)"
              >
                {{ t('TEMPLATE_ATTACHMENTS.REMOVE') }}
              </Button>
            </div>
          </template>
        </Draggable>
      </div>

      <!-- Empty State -->
      <div v-else class="text-center py-8 text-sm text-n-slate-11">
        {{ t('TEMPLATE_ATTACHMENTS.NO_FILES') }}
      </div>

      <!-- Upload Progress -->
      <div v-if="uploading" class="flex items-center justify-center gap-2 py-4">
        <woot-loading-state :message="t('TEMPLATE_ATTACHMENTS.UPLOADING')" />
      </div>
    </template>
  </div>
</template>
