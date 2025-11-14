/* global axios */
import ApiClient from './ApiClient';

class AppleMessagesImagesAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
    // DEPRECATED: This API client is deprecated and will be removed in Phase 3
    // Please migrate to appleAmbMessagesImages.js which uses the apple_amb_images endpoint
    // eslint-disable-next-line no-console
    console.warn(
      '[DEPRECATED] appleMessagesImages.js is deprecated. ' +
        'Please migrate to appleAmbMessagesImages.js (apple_amb_images endpoint)'
    );
  }

  get({ inboxId }) {
    return axios.get(`${this.url}/${inboxId}/apple_list_picker_images`);
  }

  create({ inboxId, ...imageData }) {
    return axios.post(
      `${this.url}/${inboxId}/apple_list_picker_images`,
      imageData
    );
  }

  delete({ inboxId, imageId }) {
    return axios.delete(
      `${this.url}/${inboxId}/apple_list_picker_images/${imageId}`
    );
  }
}

export default new AppleMessagesImagesAPI();
