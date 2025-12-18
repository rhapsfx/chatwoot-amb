/**
 * Axios instance getter
 * Returns the configured axios instance with authentication headers
 *
 * IMPORTANT: This must be called at request time, not at module initialization time,
 * because window.axios is set up after the app initializes.
 */
export function getAxios() {
  if (typeof window === 'undefined') {
    throw new Error('window is not defined - are you running in a browser?');
  }

  if (!window.axios) {
    throw new Error(
      'window.axios is not initialized. ' +
        'This usually means the dashboard app has not finished loading. ' +
        'Make sure to call API functions after the app has mounted.'
    );
  }

  return window.axios;
}

/**
 * Get axios instance (alias for getAxios)
 */
export const axios = () => getAxios();

export default getAxios;
