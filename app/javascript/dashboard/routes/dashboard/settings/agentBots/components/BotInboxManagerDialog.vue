<script setup>
import { ref, computed, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  bot: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const dialogRef = ref(null);
const assignedInboxes = ref([]);
const versions = ref([]);
const allInboxes = useMapGetter('inboxes/getInboxes');
const isLoading = ref(false);
const isAssignFormVisible = ref(false);

// Assign form state
const assignForm = ref({
  selectedInboxIds: [],
  selectedVersionId: null,
  priority: 1,
});

const hasBot = computed(() => props.bot && props.bot.id);

const availableInboxes = computed(() => {
  const assignedInboxIds = assignedInboxes.value.map(ai => ai.inbox_id);
  return (allInboxes.value || [])
    .filter(inbox => !assignedInboxIds.includes(inbox.id))
    .map(inbox => ({
      value: inbox.id,
      label: inbox.name,
    }));
});

const versionOptions = computed(() => {
  return [
    { value: null, label: t('AGENT_BOTS.INBOX_MANAGER.USE_CURRENT') },
    ...versions.value.map(v => ({
      value: v.id,
      label: v.version_tag,
    })),
  ];
});

const selectedVersionLabel = computed(() => {
  const option = versionOptions.value.find(
    opt => opt.value === assignForm.value.selectedVersionId
  );
  return option?.label || versionOptions.value[0].label;
});

const loadBotInboxes = async () => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    const response = await store.dispatch(
      'agentBots/getBotInboxes',
      props.bot.id
    );
    assignedInboxes.value = response?.bot_inboxes || [];
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.LOAD_ERROR'));
    assignedInboxes.value = [];
  } finally {
    isLoading.value = false;
  }
};

const loadVersions = async () => {
  if (!hasBot.value) return;

  try {
    const response = await store.dispatch('agentBots/getVersions', {
      botId: props.bot.id,
      includeArchived: false,
    });
    versions.value = response?.versions || [];
  } catch (error) {
    versions.value = [];
  }
};

const toggleInboxStatus = async inboxAssignment => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/updateBotInbox', {
      botId: props.bot.id,
      inboxId: inboxAssignment.inbox_id,
      active: !inboxAssignment.active,
    });
    await loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.STATUS_TOGGLE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const changeInboxVersion = async (inboxAssignment, versionId) => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    if (versionId) {
      await store.dispatch('agentBots/assignVersionToInbox', {
        botId: props.bot.id,
        inboxId: inboxAssignment.inbox_id,
        versionId,
      });
    } else {
      await store.dispatch('agentBots/clearInboxVersion', {
        botId: props.bot.id,
        inboxId: inboxAssignment.inbox_id,
      });
    }
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGED'));
    await loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const unassignInbox = async inboxId => {
  if (!hasBot.value) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/deleteBotInbox', {
      botId: props.bot.id,
      inboxId,
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_SUCCESS'));
    await loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const bulkAssignInboxes = async () => {
  if (!hasBot.value) return;
  if (assignForm.value.selectedInboxIds.length === 0) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.SELECT_INBOXES_ERROR'));
    return;
  }

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/bulkAssignInboxes', {
      botId: props.bot.id,
      inboxIds: assignForm.value.selectedInboxIds,
      versionId: assignForm.value.selectedVersionId,
      priority: assignForm.value.priority,
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_SUCCESS'));

    // Reset form and hide it
    assignForm.value = {
      selectedInboxIds: [],
      selectedVersionId: null,
      priority: 1,
    };
    isAssignFormVisible.value = false;

    await loadBotInboxes();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const toggleAssignForm = () => {
  isAssignFormVisible.value = !isAssignFormVisible.value;
  if (!isAssignFormVisible.value) {
    assignForm.value = {
      selectedInboxIds: [],
      selectedVersionId: null,
      priority: 1,
    };
  }
};

const getInboxName = inboxId => {
  const inbox = (allInboxes.value || []).find(i => i.id === inboxId);
  return inbox?.name || `Inbox #${inboxId}`;
};

const getVersionDisplay = inboxAssignment => {
  if (inboxAssignment.version_id) {
    const version = versions.value.find(
      v => v.id === inboxAssignment.version_id
    );
    if (version) {
      return version.version_tag;
    }
    return `v${inboxAssignment.version_id}`;
  }
  return t('AGENT_BOTS.INBOX_MANAGER.CURRENT');
};

const close = () => {
  dialogRef.value?.close();
};

watch(
  () => props.bot,
  async newBot => {
    if (newBot && newBot.id) {
      await Promise.all([loadBotInboxes(), loadVersions()]);
    }
  },
  { immediate: true, deep: true }
);

defineExpose({ open: () => dialogRef.value?.open(), close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('AGENT_BOTS.INBOX_MANAGER.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="2xl"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4">
      <!-- Header actions -->
      <div class="flex items-center justify-between">
        <span class="text-sm text-n-slate-11">
          {{ $t('AGENT_BOTS.INBOX_MANAGER.SUBTITLE', { name: bot.name }) }}
        </span>

        <Button
          v-if="!isAssignFormVisible && availableInboxes.length > 0"
          icon="i-lucide-plus"
          :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
          xs
          @click="toggleAssignForm"
        />
      </div>

      <!-- Bulk assign form -->
      <div
        v-if="isAssignFormVisible"
        class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak bg-n-slate-1"
      >
        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.SELECT_INBOXES') }}
          </label>
          <div class="flex flex-wrap gap-2">
            <label
              v-for="inbox in availableInboxes"
              :key="inbox.value"
              class="flex items-center gap-2 px-3 py-2 text-sm border rounded-lg cursor-pointer border-n-weak hover:bg-n-slate-2"
              :class="{
                'bg-n-blue-2 border-n-blue-8':
                  assignForm.selectedInboxIds.includes(inbox.value),
              }"
            >
              <input
                v-model="assignForm.selectedInboxIds"
                type="checkbox"
                :value="inbox.value"
                class="w-4 h-4 rounded border-n-weak text-n-blue-8 focus:ring-2 focus:ring-n-blue-8"
              />
              {{ inbox.label }}
            </label>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.SELECT_VERSION') }}
          </label>
          <SelectMenu
            v-model="assignForm.selectedVersionId"
            :options="versionOptions"
            :label="selectedVersionLabel"
            sub-menu-position="bottom"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.PRIORITY') }}
          </label>
          <input
            v-model.number="assignForm.priority"
            type="number"
            min="1"
            max="10"
            class="w-full px-3 py-2 text-sm bg-n-slate-1 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
          />
        </div>

        <div class="flex gap-2 justify-end">
          <Button
            faded
            slate
            xs
            :label="$t('AGENT_BOTS.FORM.CANCEL')"
            @click="toggleAssignForm"
          />
          <Button
            xs
            :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
            :disabled="assignForm.selectedInboxIds.length === 0"
            @click="bulkAssignInboxes"
          />
        </div>
      </div>

      <!-- Loading state -->
      <div
        v-if="isLoading && assignedInboxes.length === 0"
        class="flex items-center justify-center py-8"
      >
        <div class="flex items-center gap-2 text-n-slate-11">
          <i class="i-lucide-loader-2 w-5 h-5 animate-spin" />
          <span class="text-sm">{{ $t('AGENT_BOTS.LIST.LOADING') }}</span>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!isLoading && assignedInboxes.length === 0"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <i class="i-lucide-inbox w-12 h-12 mb-3 text-n-slate-8" />
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('AGENT_BOTS.INBOX_MANAGER.NO_INBOXES') }}
        </p>
        <Button
          v-if="availableInboxes.length > 0"
          icon="i-lucide-plus"
          :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
          xs
          @click="toggleAssignForm"
        />
      </div>

      <!-- Assigned inboxes table -->
      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-n-weak">
          <thead class="bg-n-slate-2">
            <tr>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.INBOX_MANAGER.INBOX') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.INBOX_MANAGER.VERSION') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.INBOX_MANAGER.PRIORITY') }}
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
              >
                {{ $t('AGENT_BOTS.INBOX_MANAGER.STATUS') }}
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
              v-for="assignment in assignedInboxes"
              :key="assignment.inbox_id"
            >
              <td class="px-4 py-3 text-sm text-n-slate-12">
                <span class="font-medium">{{
                  getInboxName(assignment.inbox_id)
                }}</span>
              </td>
              <td class="px-4 py-3 text-sm">
                <SelectMenu
                  :model-value="assignment.version_id"
                  :options="versionOptions"
                  :label="getVersionDisplay(assignment)"
                  sub-menu-position="bottom"
                  @update:model-value="changeInboxVersion(assignment, $event)"
                />
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ assignment.priority || 1 }}
              </td>
              <td class="px-4 py-3 text-sm">
                <button
                  class="flex items-center gap-1.5 px-2 py-1 rounded-md transition-colors"
                  :class="
                    assignment.active
                      ? 'bg-n-green-5 text-n-green-11 hover:bg-n-green-6'
                      : 'bg-n-slate-5 text-n-slate-11 hover:bg-n-slate-6'
                  "
                  @click="toggleInboxStatus(assignment)"
                >
                  <i
                    class="w-3 h-3"
                    :class="
                      assignment.active
                        ? 'i-lucide-check-circle'
                        : 'i-lucide-x-circle'
                    "
                  />
                  <span class="text-xs font-medium">
                    {{
                      assignment.active
                        ? $t('AGENT_BOTS.INBOX_MANAGER.ACTIVE')
                        : $t('AGENT_BOTS.INBOX_MANAGER.INACTIVE')
                    }}
                  </span>
                </button>
              </td>
              <td class="px-4 py-3">
                <div class="flex gap-1 justify-end">
                  <Button
                    v-tooltip.top="t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN')"
                    icon="i-lucide-trash-2"
                    xs
                    faded
                    ruby
                    :disabled="isLoading"
                    @click="unassignInbox(assignment.inbox_id)"
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
