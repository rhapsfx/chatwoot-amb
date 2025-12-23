import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { getAxios } from 'dashboard/helper/axios';

/**
 * Composable for handler methods management
 * Provides API integration for browsing, searching, and validating handler methods
 *
 * @param {Number} botId - Bot ID
 * @param {String} serviceName - Optional service name override
 * @returns {Object} Handler methods interface
 */
export function useHandlerMethods(botId, serviceName = null) {
  const handlerMethods = ref([]);
  const searchResults = ref([]);
  const meta = ref({});
  const isLoading = ref(false);
  const error = ref(null);

  // Get account ID from store
  const currentAccountId = useMapGetter('getCurrentAccountId');

  // Cache for handlers list with multiple cache keys
  const cache = ref(new Map());
  const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  // AbortController for cancelling search requests
  let searchController = null;

  /**
   * Build base API URL
   */
  const getBaseUrl = () => {
    const accountId = currentAccountId.value;
    return `/api/v1/accounts/${accountId}/agent_bots/${botId}/handler_methods`;
  };

  /**
   * Check if cached data is still valid
   * @param {String} key - Cache key
   * @returns {Boolean} True if cache is valid
   */
  const isCacheValid = key => {
    const cached = cache.value.get(key);
    if (!cached) return false;

    const now = Date.now();
    return now - cached.timestamp < CACHE_DURATION;
  };

  /**
   * Get data from cache
   * @param {String} key - Cache key
   * @returns {any} Cached data or null
   */
  const getFromCache = key => {
    if (isCacheValid(key)) {
      return cache.value.get(key).data;
    }
    return null;
  };

  /**
   * Store data in cache
   * @param {String} key - Cache key
   * @param {any} data - Data to cache
   */
  const setCache = (key, data) => {
    cache.value.set(key, {
      data,
      timestamp: Date.now(),
    });
  };

  /**
   * Fetch all handler methods with optional filtering
   * @param {Object} filters - Query parameters
   * @param {String} [filters.handler_type] - Filter by handler type (state, keyword, interactive, etc.)
   * @param {String} [filters.category] - Filter by category
   * @param {String} [filters.status] - Filter by status (active, deprecated, experimental)
   * @param {String} [filters.search] - Search term
   * @returns {Promise<Object>} Response with handler_methods and meta
   */
  const fetchHandlerMethods = async (filters = {}) => {
    // Prevent concurrent fetches
    if (isLoading.value) {
      // eslint-disable-next-line no-console
      console.warn('[useHandlerMethods] Fetch already in progress, skipping');
      return { handler_methods: handlerMethods.value, meta: meta.value };
    }

    isLoading.value = true;
    error.value = null;

    // Check cache first
    const cacheKey = `list:${JSON.stringify(filters)}`;
    const cached = getFromCache(cacheKey);
    if (cached) {
      handlerMethods.value = cached.handler_methods || [];
      meta.value = cached.meta || {};
      isLoading.value = false;
      return cached;
    }

    try {
      const params = { ...filters };

      if (serviceName) {
        params.service_name = serviceName;
      }

      const response = await getAxios().get(getBaseUrl(), { params });
      const data = response.data;

      handlerMethods.value = data.handler_methods || [];
      meta.value = data.meta || {};

      // Cache the response
      setCache(cacheKey, data);

      return data;
    } catch (err) {
      error.value = err.response?.data?.error || err.message;
      useAlert(
        err.response?.data?.message || 'Failed to fetch handler methods'
      );
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Get detailed metadata for a specific handler method
   * @param {String} methodName - Handler method name (e.g., 'handle_welcome')
   * @param {String} [overrideServiceName] - Optional service class name override
   * @returns {Promise<Object>} Handler method details with enriched metadata
   */
  const fetchHandlerMethod = async (methodName, overrideServiceName = null) => {
    isLoading.value = true;
    error.value = null;

    const effectiveServiceName = overrideServiceName || serviceName;

    // Check cache first
    const cacheKey = `detail:${methodName}:${effectiveServiceName || 'default'}`;
    const cached = getFromCache(cacheKey);
    if (cached) {
      isLoading.value = false;
      return cached;
    }

    try {
      const params = {};
      if (effectiveServiceName) {
        params.service_name = effectiveServiceName;
      }

      const response = await getAxios().get(`${getBaseUrl()}/${methodName}`, {
        params,
      });
      const data = response.data;

      // Cache the response
      setCache(cacheKey, data);

      return data;
    } catch (err) {
      error.value = err.response?.data?.error || err.message;

      if (err.response?.status === 404) {
        useAlert(`Handler method '${methodName}' not found`);
      } else {
        useAlert(
          err.response?.data?.message ||
            'Failed to fetch handler method details'
        );
      }

      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Search handler methods with fuzzy matching and relevance scoring
   * @param {String} query - Search query
   * @param {Object} options - Search options
   * @param {Number} [options.limit=20] - Maximum number of results
   * @param {String} [options.service_name] - Override service class name
   * @returns {Promise<Object>} Search results with match scores and reasons
   */
  const searchHandlerMethods = async (query, options = {}) => {
    // Cancel previous search request if still pending
    if (searchController) {
      searchController.abort();
    }

    if (!query || query.trim().length === 0) {
      searchResults.value = [];
      return { results: [], meta: {} };
    }

    searchController = new AbortController();
    isLoading.value = true;
    error.value = null;

    try {
      const params = {
        q: query.trim(),
        limit: options.limit || 20,
        ...(options.service_name && { service_name: options.service_name }),
      };

      if (!options.service_name && serviceName) {
        params.service_name = serviceName;
      }

      const response = await getAxios().get(`${getBaseUrl()}/search`, {
        params,
        signal: searchController.signal,
      });

      const data = response.data;
      searchResults.value = data.results || [];

      return data;
    } catch (err) {
      // Don't show error for cancelled requests
      const axios = getAxios();
      if (axios.isCancel(err)) {
        return { results: [], meta: {} };
      }

      error.value = err.response?.data?.error || err.message;

      if (err.response?.status !== 400) {
        useAlert(
          err.response?.data?.message || 'Failed to search handler methods'
        );
      }

      throw err;
    } finally {
      isLoading.value = false;
      searchController = null;
    }
  };

  /**
   * Validate a handler method exists and is properly configured
   * @param {String} methodName - Handler method name to validate
   * @param {Object} options - Validation options
   * @param {String} [options.handler_type] - Expected handler type
   * @param {String} [options.state_id] - Expected state ID (for state handlers)
   * @param {String} [options.service_name] - Override service class name
   * @returns {Promise<Object>} Validation result with { valid, errors, warnings }
   */
  const validateHandlerMethod = async (methodName, options = {}) => {
    isLoading.value = true;
    error.value = null;

    try {
      const payload = {
        method_name: methodName,
        ...(options.handler_type && { handler_type: options.handler_type }),
        ...(options.state_id && { state_id: options.state_id }),
      };

      if (options.service_name) {
        payload.service_name = options.service_name;
      } else if (serviceName) {
        payload.service_name = serviceName;
      }

      const response = await getAxios().post(
        `${getBaseUrl()}/validate`,
        payload
      );
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.error || err.message;
      useAlert(
        err.response?.data?.message || 'Failed to validate handler method'
      );
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Fetch handler methods by type (convenience method)
   * @param {String} handlerType - Handler type (state, keyword, interactive, etc.)
   * @returns {Promise<Object>} Filtered handler methods
   */
  const fetchByType = async handlerType => {
    return fetchHandlerMethods({ handler_type: handlerType });
  };

  /**
   * Fetch handler methods by category (convenience method)
   * @param {String} category - Category name
   * @returns {Promise<Object>} Filtered handler methods
   */
  const fetchByCategory = async category => {
    return fetchHandlerMethods({ category });
  };

  /**
   * Fetch handler methods by status (convenience method)
   * @param {String} status - Status (active, deprecated, experimental)
   * @returns {Promise<Object>} Filtered handler methods
   */
  const fetchByStatus = async status => {
    return fetchHandlerMethods({ status });
  };

  /**
   * Get handler method statistics
   * Useful for dashboard metrics and filtering
   * @returns {Promise<Object>} Counts by type, category, and status
   */
  const getHandlerStats = async () => {
    try {
      const data = await fetchHandlerMethods();
      const currentMeta = data.meta || {};

      return {
        total: currentMeta.total || 0,
        byType: (currentMeta.handler_types || []).reduce((acc, type) => {
          const count = handlerMethods.value.filter(
            h => h.handler_type === type
          ).length;
          acc[type] = count;
          return acc;
        }, {}),
        byCategory: (currentMeta.categories || []).reduce((acc, category) => {
          const count = handlerMethods.value.filter(
            h => h.category === category
          ).length;
          acc[category] = count;
          return acc;
        }, {}),
        byStatus: (currentMeta.statuses || []).reduce((acc, status) => {
          const count = handlerMethods.value.filter(
            h => h.status === status
          ).length;
          acc[status] = count;
          return acc;
        }, {}),
      };
    } catch (err) {
      return { total: 0, byType: {}, byCategory: {}, byStatus: {} };
    }
  };

  /**
   * Clear all cached data
   */
  const clearCache = () => {
    cache.value.clear();
  };

  // Backward compatibility aliases
  const handlers = handlerMethods;
  const fetchHandlers = fetchHandlerMethods;
  const fetchHandlerDetails = fetchHandlerMethod;
  const searchHandlers = searchHandlerMethods;
  const validateHandler = validateHandlerMethod;

  return {
    // State
    handlerMethods,
    searchResults,
    meta,
    isLoading,
    error,

    // Core API methods
    fetchHandlerMethods,
    fetchHandlerMethod,
    searchHandlerMethods,
    validateHandlerMethod,

    // Convenience methods
    fetchByType,
    fetchByCategory,
    fetchByStatus,
    getHandlerStats,

    // Cache management
    clearCache,

    // Backward compatibility (deprecated - use new names)
    handlers,
    fetchHandlers,
    fetchHandlerDetails,
    searchHandlers,
    validateHandler,
  };
}
