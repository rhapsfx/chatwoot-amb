/* global axios */
import ApiClient from './ApiClient';

class AppleListPickerImagesAPI extends ApiClient {
  constructor() {
    super('apple_list_picker_images', { accountScoped: true });
  }

  // Get all images for an inbox
  getImages(inboxId) {
    return axios.get(
      `${this.url}/accounts/${this.accountIdFromRoute}/inboxes/${inboxId}/apple_list_picker_images`
    );
  }

  // Upload image to inbox
  uploadImage(
    inboxId,
    { identifier, description, originalName, imageData, filename, contentType }
  ) {
    return axios.post(
      `${this.url}/accounts/${this.accountIdFromRoute}/inboxes/${inboxId}/apple_list_picker_images`,
      {
        identifier,
        description,
        original_name: originalName,
        image_data: imageData,
        filename,
        content_type: contentType,
      }
    );
  }

  // Delete image
  deleteImage(inboxId, imageId) {
    return axios.delete(
      `${this.url}/accounts/${this.accountIdFromRoute}/inboxes/${inboxId}/apple_list_picker_images/${imageId}`
    );
  }

  // Copy images from another inbox
  copyFromInbox(targetInboxId, sourceInboxId, identifiers) {
    return axios.post(
      `${this.url}/accounts/${this.accountIdFromRoute}/inboxes/${targetInboxId}/apple_list_picker_images/copy_from`,
      {
        source_inbox_id: sourceInboxId,
        identifiers,
      }
    );
  }

  // Bulk upload image to multiple inboxes
  bulkUpload(
    inboxIds,
    { identifier, description, originalName, imageData, filename, contentType }
  ) {
    // Pick any inbox for the URL (doesn't matter which)
    const firstInboxId = inboxIds[0];
    return axios.post(
      `${this.url}/accounts/${this.accountIdFromRoute}/inboxes/${firstInboxId}/apple_list_picker_images/bulk_upload`,
      {
        inbox_ids: inboxIds,
        identifier,
        description,
        original_name: originalName,
        image_data: imageData,
        filename,
        content_type: contentType,
      }
    );
  }
}

export default new AppleListPickerImagesAPI();
