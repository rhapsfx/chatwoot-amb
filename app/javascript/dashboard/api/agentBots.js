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
}

export default new AgentBotsAPI();
