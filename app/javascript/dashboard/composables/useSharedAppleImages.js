import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import axios from 'axios';

/**
 * Composable for managing Shared Apple Images API
 * @param {number} accountId - Account ID for API calls
 */
export function useSharedAppleImages(accountId) {
  const images = ref([]);
  const loading = ref(false);
  const error = ref(null);

  const baseUrl = `/api/v1/accounts/${accountId}/shared_apple_images`;

  /**
   * Fetch all shared images with optional filters
   * @param {Object} params - Query parameters (page, per_page, image_type, search)
   */
  const fetchImages = async (params = {}) => {
    loading.value = true;
    error.value = null;

    try {
      const response = await axios.get(baseUrl, { params });
      images.value = response.data.shared_apple_images || [];
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to fetch images');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Fetch images by type
   * @param {string} imageType - 'system', 'branding', or 'template'
   */
  const fetchImagesByType = async imageType => {
    loading.value = true;
    error.value = null;

    try {
      const url = `${baseUrl}/${imageType}_images`;
      const response = await axios.get(url);
      images.value = response.data.shared_apple_images || [];
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert(`Failed to fetch ${imageType} images`);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Fetch a single image by ID
   * @param {number} imageId - Image ID
   */
  const fetchImageById = async imageId => {
    loading.value = true;
    error.value = null;

    try {
      const response = await axios.get(`${baseUrl}/${imageId}`);
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to fetch image');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Create a new shared image
   * @param {Object} imageData - { identifier, image_type, description, base64_data }
   */
  const createImage = async imageData => {
    loading.value = true;
    error.value = null;

    try {
      const response = await axios.post(baseUrl, { image: imageData });
      useAlert('Image created successfully');
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to create image');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Update an existing shared image
   * @param {number} imageId - Image ID
   * @param {Object} imageData - Updated fields
   */
  const updateImage = async (imageId, imageData) => {
    loading.value = true;
    error.value = null;

    try {
      const response = await axios.patch(`${baseUrl}/${imageId}`, {
        image: imageData,
      });
      useAlert('Image updated successfully');
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to update image');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Delete a shared image
   * @param {number} imageId - Image ID
   */
  const deleteImage = async imageId => {
    loading.value = true;
    error.value = null;

    try {
      await axios.delete(`${baseUrl}/${imageId}`);
      useAlert('Image deleted successfully');
      images.value = images.value.filter(img => img.id !== imageId);
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to delete image');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Upload image file to existing record
   * @param {number} imageId - Image ID
   * @param {File} file - Image file
   */
  const uploadImage = async (imageId, file) => {
    loading.value = true;
    error.value = null;

    try {
      const formData = new FormData();
      formData.append('image', file);

      const response = await axios.post(
        `${baseUrl}/${imageId}/upload`,
        formData,
        {
          headers: { 'Content-Type': 'multipart/form-data' },
        }
      );
      useAlert('Image uploaded successfully');
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to upload image');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  /**
   * Remove image attachment from record
   * @param {number} imageId - Image ID
   */
  const removeImageAttachment = async imageId => {
    loading.value = true;
    error.value = null;

    try {
      const response = await axios.delete(`${baseUrl}/${imageId}/remove_image`);
      useAlert('Image attachment removed successfully');
      return response.data;
    } catch (err) {
      error.value = err.message;
      useAlert('Failed to remove image attachment');
      throw err;
    } finally {
      loading.value = false;
    }
  };

  return {
    images,
    loading,
    error,
    fetchImages,
    fetchImagesByType,
    fetchImageById,
    createImage,
    updateImage,
    deleteImage,
    uploadImage,
    removeImageAttachment,
  };
}
