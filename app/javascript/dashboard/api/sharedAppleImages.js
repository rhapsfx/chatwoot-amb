/* global axios */
import ApiClient from './ApiClient';

class SharedAppleImagesAPI extends ApiClient {
  constructor() {
    super('shared_apple_images', { accountScoped: true });
  }

  /**
   * Get shared images filtered by type
   * @param {string} imageType - 'system', 'branding', or 'template'
   * @returns {Promise}
   */
  getByType(imageType) {
    return axios.get(`${this.url}/${imageType}_images`);
  }

  /**
   * Upload image file to existing record
   * @param {number} imageId - Image ID
   * @param {FormData} formData - Form data with image file
   * @returns {Promise}
   */
  uploadImage(imageId, formData) {
    return axios.post(`${this.url}/${imageId}/upload`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  /**
   * Remove image attachment from record
   * @param {number} imageId - Image ID
   * @returns {Promise}
   */
  removeImage(imageId) {
    return axios.delete(`${this.url}/${imageId}/remove_image`);
  }
}

export default new SharedAppleImagesAPI();
