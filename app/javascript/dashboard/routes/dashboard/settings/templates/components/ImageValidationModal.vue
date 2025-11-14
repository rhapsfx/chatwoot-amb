<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import TemplatesAPI from 'dashboard/api/templates';
// Phase 1: Migrating to new apple_amb_images endpoint
import AppleAmbImagesAPI from 'dashboard/api/appleAmbImages';
// Old import (kept commented for Phase 1 rollback capability):
// import AppleListPickerImagesAPI from 'dashboard/api/appleListPickerImages';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';

const props = defineProps({
  templateId: {
    type: Number,
    required: true,
  },
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const track = useTrack();

// State
const loading = ref(false);
const validation = ref(null);
const copying = ref(false);
const selectedSource = ref(null);
const selectedTarget = ref(null);
const selectedIdentifiers = ref([]);

// Computed
const hasIssues = computed(() => {
  if (!validation.value) return false;
  return validation.value.validationResults.some(r => !r.allAvailable);
});

const inboxesWithIssues = computed(() => {
  if (!validation.value) return [];
  return validation.value.validationResults.filter(r => !r.allAvailable);
});

const inboxesComplete = computed(() => {
  if (!validation.value) return [];
  return validation.value.validationResults.filter(r => r.allAvailable);
});

const canCopy = computed(() => {
  return (
    selectedSource.value &&
    selectedTarget.value &&
    selectedIdentifiers.value.length > 0
  );
});

// Methods
const fetchValidation = async () => {
  loading.value = true;
  try {
    const response = await TemplatesAPI.validateImages(props.templateId);
    validation.value = response.data;
  } catch (error) {
    useAlert(t('TEMPLATES.IMAGE_VALIDATION.FETCH_ERROR'));
    // eslint-disable-next-line no-console
    console.error('[ImageValidation] Fetch error:', error);
  } finally {
    loading.value = false;
  }
};

const copyImages = async () => {
  if (!canCopy.value) return;

  copying.value = true;
  try {
    const response = await AppleAmbImagesAPI.copyFromInbox(
      selectedTarget.value,
      selectedSource.value,
      selectedIdentifiers.value
    );

    const { copied, errors } = response.data;

    if (copied.length > 0) {
      useAlert(
        t('TEMPLATES.IMAGE_VALIDATION.COPY_SUCCESS', {
          count: copied.length,
          total: selectedIdentifiers.value.length,
        })
      );
    }

    if (errors.length > 0) {
      useAlert(
        t('TEMPLATES.IMAGE_VALIDATION.COPY_PARTIAL_ERROR', {
          count: errors.length,
        })
      );
    }

    // Track success
    track('template_images_copied', {
      templateId: props.templateId,
      sourceInbox: selectedSource.value,
      targetInbox: selectedTarget.value,
      count: copied.length,
    });

    // Refresh validation
    await fetchValidation();

    // Reset selection
    selectedSource.value = null;
    selectedTarget.value = null;
    selectedIdentifiers.value = [];
  } catch (error) {
    useAlert(t('TEMPLATES.IMAGE_VALIDATION.COPY_ERROR'));
    // eslint-disable-next-line no-console
    console.error('[ImageValidation] Copy error:', error);
  } finally {
    copying.value = false;
  }
};

const selectAllMissing = targetInboxId => {
  const inbox = inboxesWithIssues.value.find(i => i.inboxId === targetInboxId);
  if (!inbox) return;

  selectedTarget.value = targetInboxId;
  selectedIdentifiers.value = inbox.missing;

  // Auto-select first complete inbox as source
  if (inboxesComplete.value.length > 0 && !selectedSource.value) {
    selectedSource.value = inboxesComplete.value[0].inboxId;
  }
};

const close = () => {
  emit('close');
};

onMounted(() => {
  if (props.show) {
    fetchValidation();
  }
});
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    @click.self="close"
  >
    <div
      class="bg-white dark:bg-slate-800 rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col"
    >
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
        <div class="flex items-center justify-between">
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
            {{ t('TEMPLATES.IMAGE_VALIDATION.TITLE') }}
          </h2>
          <button
            class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
            @click="close"
          >
            <i class="icon ion-close-round text-2xl" />
          </button>
        </div>
        <p
          v-if="validation"
          class="text-sm text-slate-600 dark:text-slate-400 mt-1"
        >
          {{
            t('TEMPLATES.IMAGE_VALIDATION.SUBTITLE', {
              name: validation.templateName,
              count: validation.totalIdentifiers,
            })
          }}
        </p>
      </div>

      <!-- Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <Spinner v-if="loading" />

        <div v-else-if="validation">
          <!-- Summary -->
          <div
            v-if="hasIssues"
            class="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg"
          >
            <div class="flex items-start">
              <i
                class="icon ion-alert-circled text-yellow-600 dark:text-yellow-400 text-xl mr-3"
              />
              <div>
                <h3 class="font-semibold text-yellow-900 dark:text-yellow-100">
                  {{ t('TEMPLATES.IMAGE_VALIDATION.ISSUES_FOUND') }}
                </h3>
                <p class="text-sm text-yellow-800 dark:text-yellow-200 mt-1">
                  {{
                    t('TEMPLATES.IMAGE_VALIDATION.ISSUES_DESCRIPTION', {
                      count: inboxesWithIssues.length,
                    })
                  }}
                </p>
              </div>
            </div>
          </div>

          <div
            v-else
            class="mb-6 p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg"
          >
            <div class="flex items-start">
              <i
                class="icon ion-checkmark-circled text-green-600 dark:text-green-400 text-xl mr-3"
              />
              <div>
                <h3 class="font-semibold text-green-900 dark:text-green-100">
                  {{ t('TEMPLATES.IMAGE_VALIDATION.ALL_GOOD') }}
                </h3>
                <p class="text-sm text-green-800 dark:text-green-200 mt-1">
                  {{ t('TEMPLATES.IMAGE_VALIDATION.ALL_GOOD_DESCRIPTION') }}
                </p>
              </div>
            </div>
          </div>

          <!-- Inboxes with Issues -->
          <div v-if="inboxesWithIssues.length > 0" class="mb-6">
            <h3
              class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4"
            >
              {{ t('TEMPLATES.IMAGE_VALIDATION.INBOXES_WITH_ISSUES') }}
            </h3>
            <div class="space-y-4">
              <div
                v-for="inbox in inboxesWithIssues"
                :key="inbox.inboxId"
                class="border border-slate-200 dark:border-slate-700 rounded-lg p-4"
              >
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center">
                    <i
                      class="icon ion-ios-box-outline text-slate-400 text-xl mr-2"
                    />
                    <span
                      class="font-medium text-slate-900 dark:text-slate-100"
                    >
                      {{ inbox.inboxName }}
                    </span>
                  </div>
                  <Button
                    size="small"
                    variant="smooth"
                    color-scheme="secondary"
                    @click="selectAllMissing(inbox.inboxId)"
                  >
                    <i class="icon ion-android-download mr-1" />
                    {{ t('TEMPLATES.IMAGE_VALIDATION.FIX_MISSING') }}
                  </Button>
                </div>
                <div class="text-sm">
                  <span class="text-slate-600 dark:text-slate-400">
                    {{
                      t('TEMPLATES.IMAGE_VALIDATION.MISSING_COUNT', {
                        count: inbox.missing.length,
                      })
                    }}:
                  </span>
                  <span class="ml-2 font-mono text-red-600 dark:text-red-400">
                    {{ inbox.missing.join(', ') }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Inboxes Complete -->
          <div v-if="inboxesComplete.length > 0" class="mb-6">
            <h3
              class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4"
            >
              {{ t('TEMPLATES.IMAGE_VALIDATION.INBOXES_COMPLETE') }}
            </h3>
            <div class="grid grid-cols-2 gap-4">
              <div
                v-for="inbox in inboxesComplete"
                :key="inbox.inboxId"
                class="border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 rounded-lg p-4"
              >
                <div class="flex items-center">
                  <i
                    class="icon ion-checkmark-circled text-green-600 dark:text-green-400 text-xl mr-2"
                  />
                  <span class="font-medium text-slate-900 dark:text-slate-100">
                    {{ inbox.inboxName }}
                  </span>
                </div>
                <div class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                  {{
                    t('TEMPLATES.IMAGE_VALIDATION.ALL_IMAGES_AVAILABLE', {
                      count: inbox.available.length,
                    })
                  }}
                </div>
              </div>
            </div>
          </div>

          <!-- Copy Tool -->
          <div
            v-if="hasIssues && inboxesComplete.length > 0"
            class="border-t border-slate-200 dark:border-slate-700 pt-6"
          >
            <h3
              class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4"
            >
              {{ t('TEMPLATES.IMAGE_VALIDATION.COPY_IMAGES') }}
            </h3>
            <div class="grid grid-cols-2 gap-4 mb-4">
              <div>
                <label
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
                >
                  {{ t('TEMPLATES.IMAGE_VALIDATION.SOURCE_INBOX') }}
                </label>
                <select
                  v-model="selectedSource"
                  class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100"
                >
                  <option :value="null">
                    {{ t('TEMPLATES.IMAGE_VALIDATION.SELECT_SOURCE') }}
                  </option>
                  <option
                    v-for="inbox in inboxesComplete"
                    :key="inbox.inboxId"
                    :value="inbox.inboxId"
                  >
                    {{ inbox.inboxName }}
                  </option>
                </select>
              </div>
              <div>
                <label
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
                >
                  {{ t('TEMPLATES.IMAGE_VALIDATION.TARGET_INBOX') }}
                </label>
                <select
                  v-model="selectedTarget"
                  class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100"
                >
                  <option :value="null">
                    {{ t('TEMPLATES.IMAGE_VALIDATION.SELECT_TARGET') }}
                  </option>
                  <option
                    v-for="inbox in inboxesWithIssues"
                    :key="inbox.inboxId"
                    :value="inbox.inboxId"
                  >
                    {{ inbox.inboxName }}
                  </option>
                </select>
              </div>
            </div>
            <div v-if="selectedTarget" class="mb-4">
              <label
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
              >
                {{ t('TEMPLATES.IMAGE_VALIDATION.IDENTIFIERS_TO_COPY') }}
              </label>
              <div class="flex flex-wrap gap-2">
                <label
                  v-for="identifier in inboxesWithIssues.find(
                    i => i.inboxId === selectedTarget
                  )?.missing || []"
                  :key="identifier"
                  class="inline-flex items-center"
                >
                  <input
                    v-model="selectedIdentifiers"
                    type="checkbox"
                    :value="identifier"
                    class="rounded border-slate-300 dark:border-slate-600"
                  />
                  <span
                    class="ml-2 text-sm font-mono text-slate-700 dark:text-slate-300"
                  >
                    {{ identifier }}
                  </span>
                </label>
              </div>
            </div>
            <Button
              :disabled="!canCopy || copying"
              :loading="copying"
              @click="copyImages"
            >
              <i class="icon ion-android-download mr-2" />
              {{ t('TEMPLATES.IMAGE_VALIDATION.COPY_SELECTED') }}
            </Button>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="px-6 py-4 border-t border-slate-200 dark:border-slate-700 flex justify-end"
      >
        <Button variant="smooth" color-scheme="secondary" @click="close">
          {{ t('TEMPLATES.IMAGE_VALIDATION.CLOSE') }}
        </Button>
      </div>
    </div>
  </div>
</template>
