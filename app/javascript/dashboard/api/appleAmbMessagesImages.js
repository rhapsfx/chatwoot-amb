/* global axios */
import ApiClient from './ApiClient';

class AppleAmbMessagesImagesAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  get({ inboxId }) {
    return axios.get(`${this.url}/${inboxId}/apple_amb_images`);
  }

  create({ inboxId, ...imageData }) {
    return axios.post(`${this.url}/${inboxId}/apple_amb_images`, imageData);
  }

  delete({ inboxId, imageId }) {
    return axios.delete(`${this.url}/${inboxId}/apple_amb_images/${imageId}`);
  }
}

export default new AppleAmbMessagesImagesAPI();
