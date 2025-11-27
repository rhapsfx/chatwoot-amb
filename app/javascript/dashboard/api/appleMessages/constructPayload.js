/* global axios */

/**
 * Construct Payload API Client
 *
 * Handles communication with Apple MSP Gateway for generating App Clips RichLinks.
 *
 * @module dashboard/api/appleMessages/constructPayload
 */

class ConstructPayloadAPI {
  /**
   * Call the Construct Payload API to generate App Clips richLinkDataRef
   *
   * @param {number} accountId - Account ID
   * @param {number} inboxId - Inbox ID
   * @param {Object} payload - Request payload
   * @param {string} payload.url - HTTPS URL for App Clips
   * @param {string} [payload.storeRegion='US'] - Store region (ISO 3166 alpha-2)
   * @returns {Promise<Object>} - Response with richLinkDataRef or error
   */
  static async create(accountId, inboxId, payload) {
    try {
      const response = await axios.post(
        `/api/v1/accounts/${accountId}/inboxes/${inboxId}/apple_messages/construct_payload`,
        {
          construct_payload: {
            url: payload.url,
            store_region: payload.storeRegion || 'US',
          },
        }
      );

      return response.data;
    } catch (error) {
      // Handle 400 errors (URL doesn't support App Clips)
      if (error.response?.status === 400) {
        return {
          success: false,
          error: 'This URL does not support App Clips',
          error_code: 'NO_APP_CLIPS_SUPPORT',
        };
      }

      // Re-throw for other errors to be handled by caller
      throw error;
    }
  }

  /**
   * Quick check if URL might support App Clips
   *
   * Note: This is a client-side validation only. The server will make the final determination.
   *
   * @param {string} url - URL to check
   * @returns {boolean} - True if URL might support App Clips
   */
  static mightSupportAppClips(url) {
    try {
      const urlObj = new URL(url);
      return urlObj.protocol === 'https:' && urlObj.hostname.includes('.');
    } catch {
      return false;
    }
  }
}

export default ConstructPayloadAPI;
