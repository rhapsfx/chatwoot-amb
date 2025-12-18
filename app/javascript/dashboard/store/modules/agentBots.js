import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import AgentBotsAPI from '../../api/agentBots';
import InboxesAPI from '../../api/inboxes';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  flows: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
    isUpdatingAvatar: false,
    isFetchingAgentBot: false,
    isSettingAgentBot: false,
    isDisconnecting: false,
    isFetchingFlows: false,
    isCreatingFlow: false,
    isUpdatingFlow: false,
    isDeletingFlow: false,
    isCompilingFlow: false,
  },
  agentBotInbox: {},
};

export const getters = {
  getBots($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getBot: $state => botId => {
    const [bot] = $state.records.filter(record => record.id === Number(botId));
    return bot || {};
  },
  getActiveAgentBot: $state => inboxId => {
    const associatedAgentBotId = $state.agentBotInbox[Number(inboxId)];
    return getters.getBot($state)(associatedAgentBotId);
  },
  getFlows($state) {
    return $state.flows;
  },
  getFlow: $state => flowId => {
    const [flow] = $state.flows.filter(f => f.id === Number(flowId));
    return flow || {};
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isFetching: true });
    try {
      const response = await AgentBotsAPI.get();
      commit(types.SET_AGENT_BOTS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, botData) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isCreating: true });
    try {
      // Create FormData for file upload
      const formData = new FormData();
      formData.append('name', botData.name);
      formData.append('description', botData.description);
      formData.append('bot_type', botData.bot_type || 'webhook');

      // Handle webhook URL
      if (botData.outgoing_url) {
        formData.append('outgoing_url', botData.outgoing_url);
      }

      // Handle bot_config for AMB bots
      if (botData.bot_config) {
        formData.append('bot_config', JSON.stringify(botData.bot_config));
      }

      // Add avatar file if available
      if (botData.avatar) {
        formData.append('avatar', botData.avatar);
      }

      const response = await AgentBotsAPI.create(formData);
      commit(types.ADD_AGENT_BOT, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isCreating: false });
    }
    return null;
  },

  update: async ({ commit }, { id, data }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdating: true });
    try {
      // Create FormData for file upload
      const formData = new FormData();
      formData.append('name', data.name);
      formData.append('description', data.description);
      formData.append('bot_type', data.bot_type || 'webhook');

      // Handle webhook URL
      if (data.outgoing_url) {
        formData.append('outgoing_url', data.outgoing_url);
      }

      // Handle bot_config for AMB bots
      if (data.bot_config) {
        formData.append('bot_config', JSON.stringify(data.bot_config));
      }

      if (data.avatar) {
        formData.append('avatar', data.avatar);
      }

      const response = await AgentBotsAPI.update(id, formData);
      commit(types.EDIT_AGENT_BOT, response.data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isDeleting: true });
    try {
      await AgentBotsAPI.delete(id);
      commit(types.DELETE_AGENT_BOT, id);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isDeleting: false });
    }
  },

  deleteAgentBotAvatar: async ({ commit }, id) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdatingAvatar: true });
    try {
      await AgentBotsAPI.deleteAgentBotAvatar(id);
      // Update the thumbnail to empty string after deletion
      commit(types.UPDATE_AGENT_BOT_AVATAR, { id, thumbnail: '' });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdatingAvatar: false });
    }
  },

  show: async ({ commit }, id) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingItem: true });
    try {
      const { data } = await AgentBotsAPI.show(id);
      commit(types.ADD_AGENT_BOT, data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingItem: false });
    }
  },

  fetchAgentBotInbox: async ({ commit }, inboxId) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingAgentBot: true });
    try {
      const { data } = await InboxesAPI.getAgentBot(inboxId);
      const { agent_bot: agentBot = {} } = data || {};
      commit(types.SET_AGENT_BOT_INBOX, { agentBotId: agentBot.id, inboxId });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingAgentBot: false });
    }
  },

  setAgentBotInbox: async ({ commit }, { inboxId, botId }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isSettingAgentBot: true });
    try {
      await InboxesAPI.setAgentBot(inboxId, botId);
      commit(types.SET_AGENT_BOT_INBOX, { agentBotId: botId, inboxId });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isSettingAgentBot: false });
    }
  },

  disconnectBot: async ({ commit }, { inboxId }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isDisconnecting: true });
    try {
      await InboxesAPI.setAgentBot(inboxId, null);
      commit(types.SET_AGENT_BOT_INBOX, { agentBotId: '', inboxId });
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isDisconnecting: false });
    }
  },

  resetAccessToken: async ({ commit }, botId) => {
    try {
      const response = await AgentBotsAPI.resetAccessToken(botId);
      commit(types.EDIT_AGENT_BOT, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  duplicate: async ({ commit }, botId) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isCreating: true });
    try {
      const response = await AgentBotsAPI.duplicate(botId);
      commit(types.ADD_AGENT_BOT, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isCreating: false });
    }
  },

  // Version Management Actions
  getVersions: async (_, { botId, includeArchived = false }) => {
    try {
      const response = await AgentBotsAPI.getVersions(botId, includeArchived);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  createVersion: async (_, { botId, ...versionData }) => {
    try {
      const response = await AgentBotsAPI.createVersion(botId, versionData);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  activateVersion: async ({ commit }, { botId, versionId }) => {
    try {
      const response = await AgentBotsAPI.activateVersion(botId, versionId);
      // Update the bot in the store after activation
      if (response.data) {
        commit(types.EDIT_AGENT_BOT, response.data);
      }
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  archiveVersion: async (_, { botId, versionId }) => {
    try {
      const response = await AgentBotsAPI.archiveVersion(botId, versionId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  restoreVersion: async (_, { botId, versionId }) => {
    try {
      const response = await AgentBotsAPI.restoreVersion(botId, versionId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  compareVersions: async (_, { botId, versionId, otherVersionId }) => {
    try {
      const response = await AgentBotsAPI.compareVersions(
        botId,
        versionId,
        otherVersionId
      );
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  // Inbox Management Actions
  getBotInboxes: async (_, botId) => {
    try {
      const response = await AgentBotsAPI.getBotInboxes(botId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  createBotInbox: async (_, { botId, ...inboxData }) => {
    try {
      const response = await AgentBotsAPI.createBotInbox(botId, inboxData);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  updateBotInbox: async (_, { botId, inboxId, ...inboxData }) => {
    try {
      const response = await AgentBotsAPI.updateBotInbox(
        botId,
        inboxId,
        inboxData
      );
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  deleteBotInbox: async (_, { botId, inboxId }) => {
    try {
      await AgentBotsAPI.deleteBotInbox(botId, inboxId);
      return true;
    } catch (error) {
      throwErrorMessage(error);
      return false;
    }
  },

  assignVersionToInbox: async (_, { botId, inboxId, versionId }) => {
    try {
      const response = await AgentBotsAPI.assignVersionToInbox(
        botId,
        inboxId,
        versionId
      );
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  clearInboxVersion: async (_, { botId, inboxId }) => {
    try {
      const response = await AgentBotsAPI.clearInboxVersion(botId, inboxId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  updateInboxConfigOverride: async (_, { botId, inboxId, keyPath, value }) => {
    try {
      const response = await AgentBotsAPI.updateInboxConfigOverride(
        botId,
        inboxId,
        keyPath,
        value
      );
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  bulkAssignInboxes: async (_, { botId, inboxIds, versionId, priority }) => {
    try {
      const response = await AgentBotsAPI.bulkAssignInboxes(botId, {
        inbox_ids: inboxIds,
        version_id: versionId,
        priority,
      });
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  // Flow Management Actions
  getFlows: async ({ commit }, botId) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingFlows: true });
    try {
      const response = await AgentBotsAPI.getFlows(botId);
      commit(types.SET_FLOWS, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isFetchingFlows: false });
    }
  },

  getFlow: async (_, { botId, flowId }) => {
    try {
      const response = await AgentBotsAPI.getFlow(botId, flowId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  createFlow: async ({ commit }, { botId, ...flowData }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isCreatingFlow: true });
    try {
      const response = await AgentBotsAPI.createFlow(botId, flowData);
      commit(types.ADD_FLOW, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isCreatingFlow: false });
    }
  },

  updateFlow: async ({ commit }, { botId, flowId, ...flowData }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdatingFlow: true });
    try {
      const response = await AgentBotsAPI.updateFlow(botId, flowId, flowData);
      commit(types.UPDATE_FLOW, response.data);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isUpdatingFlow: false });
    }
  },

  deleteFlow: async ({ commit }, { botId, flowId }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isDeletingFlow: true });
    try {
      await AgentBotsAPI.deleteFlow(botId, flowId);
      commit(types.DELETE_FLOW, flowId);
      return true;
    } catch (error) {
      throwErrorMessage(error);
      return false;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isDeletingFlow: false });
    }
  },

  compileFlow: async ({ commit }, { botId, flowId }) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isCompilingFlow: true });
    try {
      const response = await AgentBotsAPI.compileFlow(botId, flowId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isCompilingFlow: false });
    }
  },

  validateFlow: async (_, { botId, flowId }) => {
    try {
      const response = await AgentBotsAPI.validateFlow(botId, flowId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  simulateFlow: async (_, { botId, flowId, message, session }) => {
    try {
      const response = await AgentBotsAPI.simulateFlow(botId, flowId, {
        message,
        session,
      });
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  previewFlow: async (_, { botId, flowId }) => {
    try {
      const response = await AgentBotsAPI.previewFlow(botId, flowId);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },

  importFlowFromBotConfig: async ({ commit }, botId) => {
    commit(types.SET_AGENT_BOT_UI_FLAG, { isCreatingFlow: true });
    try {
      const response = await AgentBotsAPI.importFlowFromBotConfig(botId);
      commit(types.ADD_FLOW, response.data.flow);
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    } finally {
      commit(types.SET_AGENT_BOT_UI_FLAG, { isCreatingFlow: false });
    }
  },

  updateNode: async (_, { botId, flowId, nodeId, nodeData }) => {
    try {
      const response = await AgentBotsAPI.updateNode(
        botId,
        flowId,
        nodeId,
        nodeData
      );
      return response.data;
    } catch (error) {
      throwErrorMessage(error);
      return null;
    }
  },
};

export const mutations = {
  [types.SET_AGENT_BOT_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.ADD_AGENT_BOT]: MutationHelpers.setSingleRecord,
  [types.SET_AGENT_BOTS]: MutationHelpers.set,
  [types.EDIT_AGENT_BOT]: MutationHelpers.update,
  [types.DELETE_AGENT_BOT]: MutationHelpers.destroy,
  [types.SET_AGENT_BOT_INBOX]($state, { agentBotId, inboxId }) {
    $state.agentBotInbox = {
      ...$state.agentBotInbox,
      [inboxId]: agentBotId,
    };
  },
  [types.UPDATE_AGENT_BOT_AVATAR]($state, { id, thumbnail }) {
    const botIndex = $state.records.findIndex(bot => bot.id === id);
    if (botIndex !== -1) {
      $state.records[botIndex].thumbnail = thumbnail || '';
    }
  },
  // Flow Management Mutations
  [types.SET_FLOWS]($state, data) {
    // Handle both { flows: [...] } and direct array formats
    $state.flows = Array.isArray(data) ? data : data?.flows || [];
  },
  [types.ADD_FLOW]($state, data) {
    // Extract flow from response if needed
    const flow = data?.flow || data;
    if (!Array.isArray($state.flows)) {
      $state.flows = [];
    }
    $state.flows.push(flow);
  },
  [types.UPDATE_FLOW]($state, data) {
    // Extract flow from response if needed
    const flow = data?.flow || data;
    if (!Array.isArray($state.flows)) {
      $state.flows = [];
    }
    const index = $state.flows.findIndex(f => f.id === flow.id);
    if (index !== -1) {
      $state.flows.splice(index, 1, flow);
    } else {
      // If not found, add it
      $state.flows.push(flow);
    }
  },
  [types.DELETE_FLOW]($state, flowId) {
    $state.flows = $state.flows.filter(f => f.id !== flowId);
  },
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
