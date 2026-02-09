/* global axios */

/**
 * Parse URL API Client
 *
 * Handles OpenGraph metadata parsing for rich links
 *
 * @module dashboard/api/appleMessages/parseUrl
 */

class ParseUrlAPI {
  /**
   * Parse URL to extract OpenGraph metadata
   *
   * @param {number} accountId - Account ID
   * @param {string} url - URL to parse
   * @returns {Promise<Object>} - Response with OpenGraph metadata
   */
  static async parse(accountId, url) {
    try {
      const response = await axios.post(
        `/api/v1/accounts/${accountId}/apple_messages/parse_url`,
        { url }
      );

      return {
        success: true,
        ...response.data,
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        url,
        title: null,
        description: null,
        image_url: null,
        video_url: null,
        video_mime_type: null,
        favicon_url: null,
        site_name: null,
      };
    }
  }
}

export default ParseUrlAPI;
