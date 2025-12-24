<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import SettingsSection from 'dashboard/components/SettingsSection.vue';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const assignedBots = ref([]);
const versions = ref({});
const isLoading = ref(false);
const isAssignFormVisible = ref(false);
const allAgentBots = useMapGetter('agentBots/getBots');
const uiFlags = useMapGetter('agentBots/getUIFlags');

// Assign form state
const assignForm = ref({
  selectedBotId: null,
  selectedVersionId: null,
  priority: 1,
});

const availableBots = computed(() => {
  const assignedBotIds = assignedBots.value.map(ab => ab.agent_bot?.id);
  return (allAgentBots.value || [])
    .filter(bot => !assignedBotIds.includes(bot.id))
    .map(bot => ({
      value: bot.id,
      label: bot.name,
    }));
});

const getVersionOptions = botId => {
  const botVersions = versions.value[botId] || [];
  return [
    { value: null, label: t('AGENT_BOTS.INBOX_MANAGER.USE_CURRENT') },
    ...botVersions.map(v => ({
      value: v.id,
      label: v.version_tag,
    })),
  ];
};

const selectedBotLabel = computed(() => {
  if (!assignForm.value.selectedBotId)
    return t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_PLACEHOLDER');
  const bot = allAgentBots.value.find(
    b => b.id === assignForm.value.selectedBotId
  );
  return bot?.name || t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_PLACEHOLDER');
});

const getSelectedVersionLabel = botId => {
  const assignment = assignedBots.value.find(ab => ab.agent_bot?.id === botId);
  if (!assignment) return t('AGENT_BOTS.INBOX_MANAGER.CURRENT');

  if (assignment.version_id) {
    const version = (versions.value[botId] || []).find(
      v => v.id === assignment.version_id
    );
    return version?.version_tag || `v${assignment.version_id}`;
  }
  return t('AGENT_BOTS.INBOX_MANAGER.CURRENT');
};

const loadVersionsForBot = async botId => {
  if (!botId) return;

  try {
    const response = await store.dispatch('agentBots/getVersions', {
      botId,
      includeArchived: false,
    });
    versions.value[botId] = response?.versions || [];
  } catch (error) {
    versions.value[botId] = [];
  }
};

const loadAssignedBots = async () => {
  if (!props.inbox?.id) return;

  isLoading.value = true;
  try {
    const response = await store.dispatch(
      'agentBots/getInboxBots',
      props.inbox.id
    );
    assignedBots.value = response?.agent_bot_inboxes || [];

    // Load versions for each assigned bot in parallel
    const botIds = assignedBots.value
      .map(assignment => assignment.agent_bot?.id)
      .filter(Boolean);

    await Promise.all(botIds.map(botId => loadVersionsForBot(botId)));
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.LOAD_ERROR'));
    assignedBots.value = [];
  } finally {
    isLoading.value = false;
  }
};

const toggleBotStatus = async assignment => {
  if (!props.inbox?.id || !assignment.agent_bot?.id) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/updateBotInbox', {
      botId: assignment.agent_bot.id,
      inboxId: props.inbox.id,
      active: !assignment.active,
    });
    await loadAssignedBots();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.STATUS_TOGGLE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const changeBotVersion = async (assignment, versionId) => {
  if (!props.inbox?.id || !assignment.agent_bot?.id) return;

  isLoading.value = true;
  try {
    if (versionId) {
      await store.dispatch('agentBots/assignVersionToInbox', {
        botId: assignment.agent_bot.id,
        inboxId: props.inbox.id,
        versionId,
      });
    } else {
      await store.dispatch('agentBots/clearInboxVersion', {
        botId: assignment.agent_bot.id,
        inboxId: props.inbox.id,
      });
    }
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGED'));
    await loadAssignedBots();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.VERSION_CHANGE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const unassignBot = async assignment => {
  if (!props.inbox?.id || !assignment.agent_bot?.id) return;

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/deleteBotInbox', {
      botId: assignment.agent_bot.id,
      inboxId: props.inbox.id,
    });
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_SUCCESS'));
    await loadAssignedBots();
  } catch (error) {
    useAlert(t('AGENT_BOTS.INBOX_MANAGER.UNASSIGN_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const assignBot = async () => {
  if (!props.inbox?.id || !assignForm.value.selectedBotId) {
    useAlert(t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_ERROR'));
    return;
  }

  isLoading.value = true;
  try {
    await store.dispatch('agentBots/createBotInbox', {
      botId: assignForm.value.selectedBotId,
      inbox_id: props.inbox.id,
      version_id: assignForm.value.selectedVersionId,
      priority: assignForm.value.priority,
    });
    useAlert(t('AGENT_BOTS.BOT_CONFIGURATION.SUCCESS_MESSAGE'));

    // Reset form and hide it
    assignForm.value = {
      selectedBotId: null,
      selectedVersionId: null,
      priority: 1,
    };
    isAssignFormVisible.value = false;

    await loadAssignedBots();
  } catch (error) {
    useAlert(t('AGENT_BOTS.BOT_CONFIGURATION.ERROR_MESSAGE'));
  } finally {
    isLoading.value = false;
  }
};

const toggleAssignForm = () => {
  isAssignFormVisible.value = !isAssignFormVisible.value;
  if (!isAssignFormVisible.value) {
    assignForm.value = {
      selectedBotId: null,
      selectedVersionId: null,
      priority: 1,
    };
  }
};

const getBotName = assignment => {
  return assignment.agent_bot?.name || 'Unknown Bot';
};

watch(
  () => assignForm.value.selectedBotId,
  async newBotId => {
    if (newBotId) {
      await loadVersionsForBot(newBotId);
    }
  }
);

watch(
  () => props.inbox,
  async newInbox => {
    if (newInbox?.id) {
      await loadAssignedBots();
    }
  },
  { immediate: true, deep: true }
);

onMounted(async () => {
  await store.dispatch('agentBots/get');
  if (props.inbox?.id) {
    await loadAssignedBots();
  }
});
</script>

<template>
  <div class="mx-8">
    <SettingsSection
      :title="$t('AGENT_BOTS.BOT_CONFIGURATION.TITLE')"
      :sub-title="$t('AGENT_BOTS.BOT_CONFIGURATION.DESC')"
    >
      <LoadingState
        v-if="(uiFlags.isFetching || isLoading) && assignedBots.length === 0"
      />
      <div v-else class="flex flex-col gap-4">
        <!-- Header actions -->
        <div class="flex items-center justify-end">
          <Button
            v-if="!isAssignFormVisible && availableBots.length > 0"
            icon="i-lucide-plus"
            :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
            xs
            @click="toggleAssignForm"
          />
        </div>

        <!-- Assign form -->
        <div
          v-if="isAssignFormVisible"
          class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak bg-n-slate-1"
        >
          <div class="flex flex-col gap-2">
            <label class="text-sm font-medium text-n-slate-12">
              {{ $t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_LABEL') }}
            </label>
            <SelectMenu
              v-model="assignForm.selectedBotId"
              :options="availableBots"
              :label="selectedBotLabel"
            />
          </div>

          <div v-if="assignForm.selectedBotId" class="flex flex-col gap-2">
            <label class="text-sm font-medium text-n-slate-12">
              {{ $t('AGENT_BOTS.INBOX_MANAGER.SELECT_VERSION') }}
            </label>
            <SelectMenu
              v-model="assignForm.selectedVersionId"
              :options="getVersionOptions(assignForm.selectedBotId)"
              :label="
                getVersionOptions(assignForm.selectedBotId).find(
                  opt => opt.value === assignForm.selectedVersionId
                )?.label || $t('AGENT_BOTS.INBOX_MANAGER.USE_CURRENT')
              "
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
              max="100"
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
              :label="$t('AGENT_BOTS.BOT_CONFIGURATION.SUBMIT')"
              :disabled="!assignForm.selectedBotId"
              :is-loading="isLoading"
              @click="assignBot"
            />
          </div>
        </div>

        <!-- Empty state -->
        <div
          v-if="!isLoading && assignedBots.length === 0"
          class="flex flex-col items-center justify-center py-8 text-center"
        >
          <i class="i-lucide-inbox w-12 h-12 mb-3 text-n-slate-8" />
          <p class="text-sm text-n-slate-11 mb-4">
            {{ $t('AGENT_BOTS.INBOX_MANAGER.NO_INBOXES') }}
          </p>
          <Button
            v-if="availableBots.length > 0"
            icon="i-lucide-plus"
            :label="$t('AGENT_BOTS.INBOX_MANAGER.ASSIGN_INBOXES')"
            xs
            @click="toggleAssignForm"
          />
        </div>

        <!-- Assigned bots table -->
        <div v-else class="overflow-x-auto">
          <table class="min-w-full divide-y divide-n-weak">
            <thead class="bg-n-slate-2">
              <tr>
                <th
                  class="px-4 py-3 text-left text-xs font-medium text-n-slate-11"
                >
                  {{ $t('AGENT_BOTS.INBOX_MANAGER.BOT_NAME') }}
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
              <tr v-for="assignment in assignedBots" :key="assignment.id">
                <td class="px-4 py-3 text-sm text-n-slate-12">
                  <span class="font-medium">{{ getBotName(assignment) }}</span>
                </td>
                <td class="px-4 py-3 text-sm">
                  <SelectMenu
                    :model-value="assignment.version_id"
                    :options="getVersionOptions(assignment.agent_bot?.id)"
                    :label="getSelectedVersionLabel(assignment.agent_bot?.id)"
                    @update:model-value="changeBotVersion(assignment, $event)"
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
                    @click="toggleBotStatus(assignment)"
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
                      @click="unassignBot(assignment)"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </SettingsSection>
  </div>
</template>
