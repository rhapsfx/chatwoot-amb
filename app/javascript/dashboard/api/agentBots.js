/* global axios */
import ApiClient from './ApiClient';

class AgentBotsAPI extends ApiClient {
  constructor() {
    super('agent_bots', { accountScoped: true });
  }

  create(data) {
    return axios.post(this.url, data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  deleteAgentBotAvatar(botId) {
    return axios.delete(`${this.url}/${botId}/avatar`);
  }

  resetAccessToken(botId) {
    return axios.post(`${this.url}/${botId}/reset_access_token`);
  }

  duplicate(botId) {
    return axios.post(`${this.url}/${botId}/duplicate`);
  }

  // Version Management
  getVersions(botId, includeArchived = false) {
    return axios.get(`${this.url}/${botId}/versions`, {
      params: { include_archived: includeArchived },
    });
  }

  createVersion(botId, versionData) {
    return axios.post(`${this.url}/${botId}/versions`, versionData);
  }

  activateVersion(botId, versionId) {
    return axios.post(`${this.url}/${botId}/versions/${versionId}/activate`);
  }

  archiveVersion(botId, versionId) {
    return axios.post(`${this.url}/${botId}/versions/${versionId}/archive`);
  }

  restoreVersion(botId, versionId) {
    return axios.post(`${this.url}/${botId}/versions/${versionId}/restore`);
  }

  compareVersions(botId, versionId, otherVersionId) {
    return axios.get(
      `${this.url}/${botId}/versions/${versionId}/compare/${otherVersionId}`
    );
  }

  // Inbox Management
  getBotInboxes(botId) {
    return axios.get(`${this.url}/${botId}/inboxes`);
  }

  createBotInbox(botId, inboxData) {
    return axios.post(`${this.url}/${botId}/inboxes`, inboxData);
  }

  updateBotInbox(botId, inboxId, inboxData) {
    return axios.patch(`${this.url}/${botId}/inboxes/${inboxId}`, inboxData);
  }

  deleteBotInbox(botId, inboxId) {
    return axios.delete(`${this.url}/${botId}/inboxes/${inboxId}`);
  }

  assignVersionToInbox(botId, inboxId, versionId) {
    return axios.post(
      `${this.url}/${botId}/inboxes/${inboxId}/assign_version`,
      { version_id: versionId }
    );
  }

  clearInboxVersion(botId, inboxId) {
    return axios.post(`${this.url}/${botId}/inboxes/${inboxId}/clear_version`);
  }

  updateInboxConfigOverride(botId, inboxId, keyPath, value) {
    return axios.patch(
      `${this.url}/${botId}/inboxes/${inboxId}/config_override`,
      { key_path: keyPath, value }
    );
  }

  bulkAssignInboxes(botId, data) {
    return axios.post(`${this.url}/${botId}/inboxes/bulk_assign`, data);
  }

  // Flow Management
  getFlows(botId) {
    return axios.get(`${this.url}/${botId}/flows`);
  }

  getFlow(botId, flowId) {
    return axios.get(`${this.url}/${botId}/flows/${flowId}`);
  }

  createFlow(botId, flowData) {
    return axios.post(`${this.url}/${botId}/flows`, flowData);
  }

  updateFlow(botId, flowId, flowData) {
    return axios.patch(`${this.url}/${botId}/flows/${flowId}`, flowData);
  }

  deleteFlow(botId, flowId) {
    return axios.delete(`${this.url}/${botId}/flows/${flowId}`);
  }

  compileFlow(botId, flowId) {
    return axios.post(`${this.url}/${botId}/flows/${flowId}/compile`);
  }

  validateFlow(botId, flowId) {
    return axios.post(`${this.url}/${botId}/flows/${flowId}/validate`);
  }

  simulateFlow(botId, flowId, payload) {
    return axios.post(`${this.url}/${botId}/flows/${flowId}/simulate`, payload);
  }

  previewFlow(botId, flowId) {
    return axios.get(`${this.url}/${botId}/flows/${flowId}/preview`);
  }

  importFlowFromBotConfig(botId) {
    return axios.post(`${this.url}/${botId}/flows/import_from_bot_config`);
  }

  getFlowTemplates(accountId, botId) {
    return axios.get(`${this.url}/${botId}/flows/templates`);
  }

  updateNode(botId, flowId, nodeId, nodeData) {
    return axios.patch(
      `${this.url}/${botId}/flows/${flowId}/nodes/${nodeId}`,
      nodeData
    );
  }

  // Handler Methods
  getHandlerMethods(botId, params = {}) {
    return axios.get(`${this.url}/${botId}/handler_methods`, { params });
  }

  getHandlerMethod(botId, methodName) {
    return axios.get(`${this.url}/${botId}/handler_methods/${methodName}`);
  }

  searchHandlerMethods(botId, query, params = {}) {
    return axios.get(`${this.url}/${botId}/handler_methods/search`, {
      params: { q: query, ...params },
    });
  }

  validateHandlerMethod(botId, methodName, params = {}) {
    return axios.post(`${this.url}/${botId}/handler_methods/validate`, {
      method_name: methodName,
      ...params,
    });
  }

  // Bot Action Templates
  getBotActionTemplates(accountId, botId) {
    return axios.get(`${this.url}/${botId}/bot_action_templates`);
  }

  updateBotActionTemplate(botId, templateId, templateData) {
    return axios.patch(
      `${this.url}/${botId}/bot_action_templates/${templateId}`,
      { template: templateData }
    );
  }
}

export default new AgentBotsAPI();
