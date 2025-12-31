<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  bot: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const dialogRef = ref(null);
const versions = ref([]);
const isLoading = ref(false);
const isCreateFormVisible = ref(false);
const includeArchived = ref(false);

// Create version form state
const createForm = ref({
  versionName: '',
  description: '',
  tag: '',
});

const hasBot = computed(() => props.bot && props.bot.id);

const loadVersions = async () => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    const response = await store.dispatch('agentBots/getVersions', {
      botId: props.bot.id,
      includeArchived: includeArchived.value,
    });
    versions.value = response?.versions || [];
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.LOAD_ERROR'));
    versions.value = [];
  } finally {
    isLoading.value = false;
  }
};

const activateVersion = async versionId => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/activateVersion', {
      botId: props.bot.id,
      versionId,
    });
    useAlert(t('AGENT_BOTS.VERSIONS.ACTIVATE_SUCCESS'));
    await loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.ACTIVATE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const archiveVersion = async versionId => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/archiveVersion', {
      botId: props.bot.id,
      versionId,
    });
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_SUCCESS'));
    await loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const restoreVersion = async versionId => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/restoreVersion', {
      botId: props.bot.id,
      versionId,
    });
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_SUCCESS'));
    await loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.ARCHIVE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const createVersion = async () => {
  if (!hasBot.value) return;
  if (!createForm.value.versionName.trim()) {
    useAlert(t('AGENT_BOTS.VERSIONS.CREATE_ERROR'));
    return;
  }

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/createVersion', {
      botId: props.bot.id,
      version_tag: createForm.value.versionName,
      description: createForm.value.description,
      notes: createForm.value.tag,
    });
    useAlert(t('AGENT_BOTS.VERSIONS.CREATE_SUCCESS'));

    // Reset form and hide it
    createForm.value = {
      versionName: '',
      description: '',
      tag: '',
    };
    isCreateFormVisible.value = false;

    await loadVersions();
  } catch (error) {
    useAlert(t('AGENT_BOTS.VERSIONS.CREATE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const toggleCreateForm = () => {
  isCreateFormVisible.value = !isCreateFormVisible.value;
  if (!isCreateFormVisible.value) {
    createForm.value = {
      versionName: '',
      description: '',
      tag: '',
    };
  }
};

const formatDate = dateString => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

const close = () => {
  dialogRef.value?.close();
};

watch(
  () => props.bot,
  async newBot => {
    if (newBot && newBot.id) {
      await loadVersions();
    }
  },
  { immediate: true, deep: true }
);

watch(includeArchived, () => {
  loadVersions();
});

defineExpose({ open: () => dialogRef.value?.open(), close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('AGENT_BOTS.VERSIONS.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="2xl"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4">
      <!-- Header actions -->
      <div class="flex items-center justify-between gap-2">
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <input
            v-model="includeArchived"
            type="checkbox"
            class="w-4 h-4 rounded border-n-weak text-n-blue-8 focus:ring-2 focus:ring-n-blue-8"
          />
          {{ $t('AGENT_BOTS.VERSIONS.INCLUDE_ARCHIVED') }}
        </label>

        <Button
          v-if="!isCreateFormVisible"
          icon="i-lucide-plus"
          :label="$t('AGENT_BOTS.VERSIONS.CREATE_NEW')"
          xs
          @click="toggleCreateForm"
        />
      </div>

      <!-- Create version form -->
      <div
        v-if="isCreateFormVisible"
        class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak bg-n-slate-1"
      >
        <Input
          id="version-name"
          v-model="createForm.versionName"
          :label="$t('AGENT_BOTS.VERSIONS.VERSION_NAME')"
          :placeholder="$t('AGENT_BOTS.VERSIONS.VERSION_NAME_PLACEHOLDER')"
        />

        <TextArea
          id="version-description"
          v-model="createForm.description"
          :label="$t('AGENT_BOTS.VERSIONS.DESCRIPTION')"
          :placeholder="$t('AGENT_BOTS.VERSIONS.DESCRIPTION_PLACEHOLDER')"
        />

        <Input
          id="version-tag"
          v-model="createForm.tag"
          :label="$t('AGENT_BOTS.VERSIONS.TAG')"
          :placeholder="$t('AGENT_BOTS.VERSIONS.TAG_PLACEHOLDER')"
        />

        <div class="flex gap-2 justify-end">
          <Button
            faded
            slate
            xs
            :label="$t('AGENT_BOTS.FORM.CANCEL')"
            @click="toggleCreateForm"
          />
          <Button
            xs
            :label="$t('AGENT_BOTS.VERSIONS.CREATE_NEW')"
            :disabled="!createForm.versionName.trim()"
            @click="createVersion"
          />
        </div>
      </div>

      <!-- Loading state -->
      <div
        v-if="isLoading && versions.length === 0"
        class="flex items-center justify-center py-8"
      >
        <div class="flex items-center gap-2 text-n-slate-11">
          <i class="i-lucide-loader-2 w-5 h-5 animate-spin" />
          <span class="text-sm">{{ $t('AGENT_BOTS.LIST.LOADING') }}</span>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!isLoading && versions.length === 0"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <i class="i-lucide-git-branch w-12 h-12 mb-3 text-n-slate-8" />
        <p class="text-sm text-n-slate-11">
          {{ $t('AGENT_BOTS.VERSIONS.NO_VERSIONS') }}
        </p>
      </div>

      <!-- Versions table -->
      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-n-weak">
          <thead class="bg-n-slate-2">
            <tr>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.VERSION') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.NAME') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.TAG') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.CREATED_BY') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.CREATED_AT') }}
              </th>
              <th
                class="px-4 py-3 text-right text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.VERSIONS.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="version in versions"
              :key="version.id"
              :class="{ 'bg-n-blue-2': version.is_active }"
            >
              <td class="px-4 py-3 text-sm">
                <div class="flex items-center gap-2">
                  <span class="font-mono text-n-slate-12">
                    {{ version.version_tag }}
                  </span>
                  <span
                    v-if="version.is_active"
                    class="text-xs bg-n-blue-8 text-white rounded-full px-2 py-0.5"
                  >
                    {{ $t('AGENT_BOTS.VERSIONS.ACTIVE') }}
                  </span>
                  <span
                    v-if="version.archived"
                    class="text-xs bg-n-slate-8 text-white rounded-full px-2 py-0.5"
                  >
                    {{ $t('AGENT_BOTS.VERSIONS.ARCHIVED') }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-12">
                <div class="flex flex-col">
                  <span
                    v-if="version.description"
                    class="text-xs text-n-slate-11"
                  >
                    {{ version.description }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                <span
                  v-if="version.tag"
                  class="text-xs bg-n-slate-5 rounded px-2 py-1"
                >
                  {{ version.tag }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ version.created_by || '—' }}
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ formatDate(version.created_at) }}
              </td>
              <td class="px-4 py-3">
                <div class="flex gap-1 justify-end">
                  <Button
                    v-if="!version.is_active && !version.archived"
                    v-tooltip.top="t('AGENT_BOTS.VERSIONS.ACTIVATE')"
                    icon="i-lucide-check-circle"
                    xs
                    faded
                    slate
                    :disabled="isLoading"
                    @click="activateVersion(version.id)"
                  />
                  <Button
                    v-if="!version.is_active && !version.archived"
                    v-tooltip.top="t('AGENT_BOTS.VERSIONS.ARCHIVE')"
                    icon="i-lucide-archive"
                    xs
                    faded
                    slate
                    :disabled="isLoading"
                    @click="archiveVersion(version.id)"
                  />
                  <Button
                    v-if="version.archived"
                    v-tooltip.top="t('AGENT_BOTS.VERSIONS.RESTORE')"
                    icon="i-lucide-archive-restore"
                    xs
                    faded
                    slate
                    :disabled="isLoading"
                    @click="restoreVersion(version.id)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Footer actions -->
      <div class="flex justify-end pt-2">
        <Button
          faded
          slate
          :label="$t('AGENT_BOTS.FORM.CANCEL')"
          @click="close"
        />
      </div>
    </div>
  </Dialog>
</template>
