<script setup>
import { ref, computed, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AgentBotModal from './components/AgentBotModal.vue';
import BotVersionHistoryDialog from './components/BotVersionHistoryDialog.vue';
import BotInboxManagerDialog from './components/BotInboxManagerDialog.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const MODAL_TYPES = {
  CREATE: 'create',
  EDIT: 'edit',
};

const store = useStore();
const { t } = useI18n();

const agentBots = useMapGetter('agentBots/getBots');
const uiFlags = useMapGetter('agentBots/getUIFlags');

const selectedBot = ref({});
const loading = ref({});
const modalType = ref(MODAL_TYPES.CREATE);
const agentBotModalRef = ref(null);
const agentBotDeleteDialogRef = ref(null);
const versionHistoryDialogRef = ref(null);
const inboxManagerDialogRef = ref(null);

const tableHeaders = computed(() => {
  return [
    t('AGENT_BOTS.LIST.TABLE_HEADER.DETAILS'),
    t('AGENT_BOTS.LIST.TABLE_HEADER.URL'),
  ];
});

const selectedBotName = computed(() => selectedBot.value?.name || '');

const openAddModal = () => {
  modalType.value = MODAL_TYPES.CREATE;
  selectedBot.value = {};
  agentBotModalRef.value.dialogRef.open();
};

const openEditModal = bot => {
  modalType.value = MODAL_TYPES.EDIT;
  selectedBot.value = bot;
  agentBotModalRef.value.dialogRef.open();
};

const openDeletePopup = bot => {
  selectedBot.value = bot;
  agentBotDeleteDialogRef.value.open();
};

const deleteAgentBot = async id => {
  try {
    await store.dispatch('agentBots/delete', id);
    useAlert(t('AGENT_BOTS.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_BOTS.DELETE.API.ERROR_MESSAGE'));
  } finally {
    loading.value[id] = false;
    selectedBot.value = {};
  }
};

const confirmDeletion = () => {
  loading.value[selectedBot.value.id] = true;
  deleteAgentBot(selectedBot.value.id);
  agentBotDeleteDialogRef.value.close();
};

const openVersionHistory = bot => {
  selectedBot.value = bot;
  versionHistoryDialogRef.value.open();
};

const openInboxManager = bot => {
  selectedBot.value = bot;
  inboxManagerDialogRef.value.open();
};

const duplicateBot = async () => {
  // TODO: Implement duplicate functionality when backend endpoint is ready
  useAlert(t('AGENT_BOTS.DUPLICATE.NOT_IMPLEMENTED'));
};

onMounted(() => {
  store.dispatch('agentBots/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('AGENT_BOTS.LIST.LOADING')"
    :no-records-found="!agentBots.length"
    :no-records-message="t('AGENT_BOTS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('AGENT_BOTS.HEADER')"
        :description="t('AGENT_BOTS.DESCRIPTION')"
        :link-text="t('AGENT_BOTS.LEARN_MORE')"
        feature-name="agent_bots"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('AGENT_BOTS.ADD.TITLE')"
            @click="openAddModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <table class="min-w-full overflow-x-auto divide-y divide-n-strong">
        <thead>
          <th
            v-for="thHeader in tableHeaders"
            :key="thHeader"
            class="py-4 font-semibold text-left ltr:pr-4 rtl:pl-4 text-n-slate-11"
          >
            {{ thHeader }}
          </th>
        </thead>
        <tbody class="flex-1 divide-y divide-n-weak text-n-slate-12">
          <tr v-for="bot in agentBots" :key="bot.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <div class="flex flex-row items-center gap-4">
                <Avatar
                  :name="bot.name"
                  :src="bot.thumbnail"
                  :size="40"
                  rounded-full
                />
                <div>
                  <span class="block font-medium break-words">
                    {{ bot.name }}
                    <!-- System bot badge -->
                    <span
                      v-if="bot.system_bot"
                      class="text-xs text-n-slate-12 bg-n-blue-5 inline-block rounded-md py-0.5 px-1 ltr:ml-1 rtl:mr-1"
                    >
                      {{ $t('AGENT_BOTS.GLOBAL_BOT_BADGE') }}
                    </span>
                    <!-- Bot type badge -->
                    <span
                      class="text-xs inline-block rounded-md py-0.5 px-1 ltr:ml-1 rtl:mr-1"
                      :class="{
                        'bg-n-blue-5 text-n-slate-12':
                          bot.bot_type === 'apple_messages_for_business',
                        'bg-n-slate-5 text-n-slate-11':
                          bot.bot_type === 'webhook',
                      }"
                    >
                      {{
                        bot.bot_type === 'apple_messages_for_business'
                          ? $t('AGENT_BOTS.TYPES.AMB')
                          : $t('AGENT_BOTS.TYPES.WEBHOOK')
                      }}
                    </span>
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ bot.description }}
                  </span>
                  <!-- Version and Inbox Info (for AMB bots only) -->
                  <div
                    v-if="bot.bot_type === 'apple_messages_for_business'"
                    class="flex gap-2 mt-1 text-xs text-n-slate-11"
                  >
                    <span
                      v-if="bot.active_version"
                      class="flex items-center gap-1"
                    >
                      <i class="i-lucide-git-branch w-3 h-3" />
                      {{
                        $t('AGENT_BOTS.VERSION', {
                          version: bot.active_version.version_tag,
                        })
                      }}
                    </span>
                    <span
                      v-if="bot.inbox_count"
                      class="flex items-center gap-1"
                    >
                      <i class="i-lucide-inbox w-3 h-3" />
                      {{ bot.inbox_count }} {{ $t('AGENT_BOTS.INBOXES') }}
                    </span>
                  </div>
                </div>
              </div>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 text-sm">
              {{ bot.outgoing_url || bot.bot_config?.webhook_url }}
            </td>
            <td class="py-4 min-w-xs">
              <div class="flex gap-1 justify-end">
                <!-- Version history button (AMB bots only) -->
                <Button
                  v-if="
                    bot.bot_type === 'apple_messages_for_business' &&
                    !bot.system_bot
                  "
                  v-tooltip.top="t('AGENT_BOTS.VERSION_HISTORY')"
                  icon="i-lucide-history"
                  slate
                  xs
                  faded
                  @click="openVersionHistory(bot)"
                />
                <!-- Inbox manager button (AMB bots only) -->
                <Button
                  v-if="
                    bot.bot_type === 'apple_messages_for_business' &&
                    !bot.system_bot
                  "
                  v-tooltip.top="t('AGENT_BOTS.MANAGE_INBOXES')"
                  icon="i-lucide-inbox"
                  slate
                  xs
                  faded
                  @click="openInboxManager(bot)"
                />
                <!-- Duplicate button -->
                <Button
                  v-if="!bot.system_bot"
                  v-tooltip.top="t('AGENT_BOTS.DUPLICATE')"
                  icon="i-lucide-copy"
                  slate
                  xs
                  faded
                  @click="duplicateBot(bot)"
                />
                <!-- Edit button -->
                <Button
                  v-if="!bot.system_bot"
                  v-tooltip.top="t('AGENT_BOTS.EDIT.BUTTON_TEXT')"
                  icon="i-lucide-pen"
                  slate
                  xs
                  faded
                  :is-loading="loading[bot.id]"
                  @click="openEditModal(bot)"
                />
                <!-- Delete button -->
                <Button
                  v-if="!bot.system_bot"
                  v-tooltip.top="t('AGENT_BOTS.DELETE.BUTTON_TEXT')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  :is-loading="loading[bot.id]"
                  @click="openDeletePopup(bot)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <AgentBotModal
      ref="agentBotModalRef"
      :type="modalType"
      :selected-bot="selectedBot"
    />

    <BotVersionHistoryDialog ref="versionHistoryDialogRef" :bot="selectedBot" />

    <BotInboxManagerDialog ref="inboxManagerDialogRef" :bot="selectedBot" />

    <Dialog
      ref="agentBotDeleteDialogRef"
      type="alert"
      :title="t('AGENT_BOTS.DELETE.CONFIRM.TITLE')"
      :description="
        t('AGENT_BOTS.DELETE.CONFIRM.MESSAGE', { name: selectedBotName })
      "
      :is-loading="uiFlags.isDeleting"
      :confirm-button-label="t('AGENT_BOTS.DELETE.CONFIRM.YES')"
      :cancel-button-label="t('AGENT_BOTS.DELETE.CONFIRM.NO')"
      @confirm="confirmDeletion"
    />
  </SettingsLayout>
</template>
