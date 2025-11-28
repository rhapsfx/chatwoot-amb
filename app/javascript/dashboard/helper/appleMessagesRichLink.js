// Apple Messages Rich Link Helper
// Automatic URL detection and Rich Link conversion for Apple Messages conversations

import ConstructPayloadAPI from '../api/appleMessages/constructPayload';
import ParseUrlAPI from '../api/appleMessages/parseUrl';

// Enhanced URL regex that detects URLs with and without protocol
// More permissive path matching to handle complex URLs with special characters
export const URL_REGEX =
  /(?:https?:\/\/)?(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s<>"{}|\\^`[\]]+)?/gi;

// Preprocess text to join URLs split across lines
// This handles cases where users copy-paste URLs that get line-wrapped
export const preprocessTextForURLDetection = text => {
  if (!text || typeof text !== 'string') return text;

  // First pass: Join URL parts that are split across lines
  // Pattern: URL-like text followed by whitespace followed by URL continuation
  let processed = text.replace(
    /(https?:\/\/[^\s]+)\s+([a-zA-Z0-9/_.-]+)/g,
    (match, part1, part2) => {
      // Only join if part2 looks like a URL path continuation
      if (/^[a-zA-Z0-9/_.-]/.test(part2) && !part2.includes(' ')) {
        return `${part1}${part2}`;
      }
      return match;
    }
  );

  // Second pass: Handle domains followed by paths on new lines
  // Example: "apple.com\n/path/to/video.mp4" -> "apple.com/path/to/video.mp4"
  processed = processed.replace(
    /([a-zA-Z0-9-]+\.[a-zA-Z]{2,})([\s\n]+)(\/[^\s]+)/g,
    '$1$3'
  );

  return processed;
};

export const isAppleMessagesConversation = conversation => {
  return (
    conversation?.inbox?.channel_type === 'Channel::AppleMessagesForBusiness'
  );
};

// Normalize URL by adding protocol if missing
export const normalizeURL = url => {
  if (!url || typeof url !== 'string') return url;

  // Already has protocol
  if (url.match(/^https?:\/\//)) return url;

  // Add https:// protocol for www. and domain.tld patterns
  if (url.match(/^(www\.|[a-zA-Z0-9-]+\.[a-zA-Z]{2,})/)) {
    return `https://${url}`;
  }

  return url;
};

export const detectURLsInText = text => {
  if (!text || typeof text !== 'string') return [];

  // Preprocess text to join URLs split across lines
  const processedText = preprocessTextForURLDetection(text);

  const urls = processedText.match(URL_REGEX);
  // Normalize URLs by adding protocol if missing
  return urls ? [...new Set(urls.map(normalizeURL))] : [];
};

export const shouldAutoConvertToRichLink = conversation => {
  // Always auto-convert URLs for Apple Messages conversations
  return isAppleMessagesConversation(conversation);
};

// Split message into parts: text before URL, URL, text after URL
export const splitMessageByURLs = text => {
  if (!text || typeof text !== 'string')
    return [{ type: 'text', content: text }];

  // Preprocess text to join URLs split across lines
  const processedText = preprocessTextForURLDetection(text);

  const parts = [];
  let lastIndex = 0;

  // Reset regex to start from beginning
  const urlRegex = new RegExp(URL_REGEX.source, URL_REGEX.flags);
  let match = urlRegex.exec(processedText);

  while (match !== null) {
    // Add text before URL if exists
    if (match.index > lastIndex) {
      const beforeText = processedText.slice(lastIndex, match.index).trim();
      if (beforeText) {
        parts.push({ type: 'text', content: beforeText });
      }
    }

    // Add URL as Rich Link (normalize URL first)
    parts.push({ type: 'url', content: normalizeURL(match[0]) });

    lastIndex = match.index + match[0].length;
    match = urlRegex.exec(processedText);
  }

  // Add remaining text after last URL if exists
  if (lastIndex < processedText.length) {
    const afterText = processedText.slice(lastIndex).trim();
    if (afterText) {
      parts.push({ type: 'text', content: afterText });
    }
  }

  // If no URLs found, return original text
  if (parts.length === 0) {
    parts.push({ type: 'text', content: processedText });
  }

  return parts;
};

export const extractMainURL = text => {
  const urls = detectURLsInText(text);
  return urls.length > 0 ? urls[0] : null;
};

// Helper to extract domain from URL for fallback display
const extractDomainFromURL = url => {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname.replace('www.', '');
  } catch {
    return 'Website';
  }
};

// Check if URL is a direct video file
// Video URLs should use manual rich link with video assets, not App Clips
const isDirectVideoURL = url => {
  if (!url || typeof url !== 'string') return false;

  const videoExtensions = [
    '.mp4',
    '.mov',
    '.m4v',
    '.avi',
    '.wmv',
    '.flv',
    '.webm',
    '.mkv',
    '.3gp',
  ];

  const lowerURL = url.toLowerCase();
  return videoExtensions.some(ext => lowerURL.endsWith(ext));
};

// Check if URL is an Apple Maps link
// Apple Maps links should use manual rich link with location preview, not App Clips
const isAppleMapsURL = url => {
  if (!url || typeof url !== 'string') return false;

  // Match Apple Maps patterns:
  // - maps.apple.com/frame?... (frame URLs with parameters: center, span, distance, heading, pitch, map mode, tracking)
  // - maps.apple.com/?... (with query params)
  // - maps.apple/p/... (short URLs)
  // - maps.apple.com/place/... (place URLs)
  return (
    url.includes('maps.apple.com') ||
    url.includes('maps.apple/') ||
    /maps\.apple\.com\/frame\?/.test(url) ||
    /maps\.apple\.com\/\?/.test(url) ||
    /maps\.apple\.com\/place\//.test(url) ||
    /maps\.apple\/p\//.test(url)
  );
};

export const createRichLinkPreview = async (url, conversation = null) => {
  try {
    // Normalize URL before processing
    const normalizedURL = normalizeURL(url);

    // Get account ID from current URL path
    const accountId = window.location.pathname.match(/accounts\/(\d+)/)?.[1];
    if (!accountId) {
      throw new Error('Account ID not found');
    }

    // ⚠️ SKIP App Clips for:
    // 1. Direct video URLs - they need manual rich link with video assets
    // 2. Apple Maps URLs - they need manual rich link with location preview
    const skipAppClips =
      isDirectVideoURL(normalizedURL) || isAppleMapsURL(normalizedURL);
    if (skipAppClips) {
      if (isDirectVideoURL(normalizedURL)) {
        // eslint-disable-next-line no-console
        console.log(
          '[Rich Link] Direct video URL detected, skipping App Clips:',
          normalizedURL
        );
      } else if (isAppleMapsURL(normalizedURL)) {
        // eslint-disable-next-line no-console
        console.log(
          '[Rich Link] Apple Maps URL detected, skipping App Clips:',
          normalizedURL
        );
      }
    }

    // ✅ PRIORITY 1: Try App Clips (Construct Payload API) if conversation available
    // BUT skip for direct video URLs and Apple Maps URLs - they need manual rich link
    if (conversation?.inbox_id && !skipAppClips) {
      try {
        // Check if URL might support App Clips (basic HTTPS validation)
        if (ConstructPayloadAPI.mightSupportAppClips(normalizedURL)) {
          // Attempt to generate App Clips richLinkDataRef
          const constructResult = await ConstructPayloadAPI.create(
            accountId,
            conversation.inbox_id,
            {
              url: normalizedURL,
              storeRegion: 'US', // Default to US, could be made configurable
            }
          );

          // Success! URL supports App Clips
          if (constructResult.success && constructResult.rich_link_data_ref) {
            return {
              success: true,
              isAppClips: true,
              richLinkData: {
                url: normalizedURL,
                rich_link_data_ref: constructResult.rich_link_data_ref,
                // App Clips don't need title/description/image as they're hosted by Apple
              },
            };
          }

          // If error_code is NO_APP_CLIPS_SUPPORT, fall through to OpenGraph
          // For other errors, silently fall through to OpenGraph
        }
      } catch (error) {
        // Construct Payload API failed, fall through to OpenGraph
        // Silently catch and continue to OpenGraph fallback
      }
    }

    // ✅ PRIORITY 2: Fallback to OpenGraph scraping (manual rich link)
    // This is also used for direct video URLs and Apple Maps URLs (bypassing App Clips)
    if (skipAppClips) {
      if (isDirectVideoURL(normalizedURL)) {
        // eslint-disable-next-line no-console
        console.log(
          '[Rich Link] Using manual rich link for video URL (video assets will be added by backend)'
        );
      } else if (isAppleMapsURL(normalizedURL)) {
        // eslint-disable-next-line no-console
        console.log(
          '[Rich Link] Using manual rich link for Apple Maps (location preview will be shown)'
        );
      }
    }

    const data = await ParseUrlAPI.parse(accountId, normalizedURL);

    return {
      success: data.success,
      isAppClips: false,
      richLinkData: {
        url: data.url || normalizedURL,
        title: data.title,
        description: data.description,
        image_url: data.image_url,
        video_url: data.video_url, // Video URL from OpenGraph
        video_mime_type: data.video_mime_type, // Video MIME type from OpenGraph
        favicon_url: data.favicon_url,
        image_data: data.image_url, // For backward compatibility
        image_mime_type: 'image/jpeg',
        site_name: data.site_name,
      },
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      // Fallback data
      richLinkData: {
        url,
        title: extractDomainFromURL(url),
        description: null,
        image_url: null,
        site_name: extractDomainFromURL(url),
      },
    };
  }
};

export const formatRichLinkMessage = (richLinkData, originalText) => {
  return {
    content: originalText,
    content_type: 'apple_rich_link',
    content_attributes: {
      url: richLinkData.url,
      title: richLinkData.title,
      description: richLinkData.description,
      image_url: richLinkData.image_url,
      favicon_url: richLinkData.favicon_url,
      site_name: richLinkData.site_name,
    },
  };
};

// Debounced URL detection for real-time preview
export const createDebouncedURLDetector = (callback, delay = 500) => {
  let timeoutId;

  return (text, conversation) => {
    clearTimeout(timeoutId);

    timeoutId = setTimeout(() => {
      if (shouldAutoConvertToRichLink(conversation, text)) {
        const url = extractMainURL(text);
        if (url) {
          callback(url, text);
        }
      }
    }, delay);
  };
};

// Rich Link suggestion for agents
export const createRichLinkSuggestion = (url, richLinkData) => {
  return {
    type: 'rich_link_suggestion',
    url,
    title: richLinkData.title,
    description: richLinkData.description,
    image_url: richLinkData.image_url,
    action: 'convert_to_rich_link',
  };
};

// Process message content and create multiple messages for Apple Messages
export const processMessageForAppleMessages = async (
  messageContent,
  conversation
) => {
  if (!isAppleMessagesConversation(conversation)) {
    return [{ type: 'text', content: messageContent }];
  }

  const parts = splitMessageByURLs(messageContent);

  // ✅ NEW APPROACH: If message contains URLs, create a single rich link with full text
  // This avoids Apple's message ordering issues entirely
  const hasUrls = parts.some(part => part.type === 'url');

  if (hasUrls) {
    // Find the first URL for rich link generation
    const urlPart = parts.find(part => part.type === 'url');

    if (urlPart) {
      // Convert URL to Rich Link with full message text
      // Pass conversation to enable App Clips detection
      const richLinkPreview = await createRichLinkPreview(
        urlPart.content,
        conversation
      );

      if (richLinkPreview.success) {
        return [
          {
            type: 'rich_link',
            content: messageContent, // Use full original message as content
            content_type: 'apple_rich_link',
            content_attributes: {
              ...richLinkPreview.richLinkData,
              // Add the full message text as title or description if not present
              title: richLinkPreview.richLinkData.title || messageContent,
              description:
                richLinkPreview.richLinkData.description ||
                `${messageContent}\n\n${richLinkPreview.richLinkData.url}`,
            },
          },
        ];
      }
    }
  }

  // Fallback: Process as separate messages (original behavior)
  const processedMessages = await Promise.all(
    parts.map(async part => {
      if (part.type === 'text') {
        return {
          type: 'text',
          content: part.content,
          content_type: 'text',
          content_attributes: {},
        };
      }

      if (part.type === 'url') {
        // Convert URL to Rich Link
        // Pass conversation to enable App Clips detection
        const richLinkPreview = await createRichLinkPreview(
          part.content,
          conversation
        );

        if (richLinkPreview.success) {
          return {
            type: 'rich_link',
            content: part.content, // Original URL as fallback
            content_type: 'apple_rich_link',
            content_attributes: richLinkPreview.richLinkData,
          };
        }

        // Fallback to text if Rich Link fails
        return {
          type: 'text',
          content: part.content,
          content_type: 'text',
          content_attributes: {},
        };
      }

      return null;
    })
  );

  return processedMessages.filter(Boolean);
};

// Process canned response for automatic Rich Link conversion
export const processCannedResponseForAppleMessages = async (
  cannedResponseContent,
  conversation
) => {
  return processMessageForAppleMessages(cannedResponseContent, conversation);
};

// Apple Messages specific URL patterns that work well as Rich Links
export const APPLE_FRIENDLY_DOMAINS = [
  'apple.com',
  'apps.apple.com',
  'support.apple.com',
  'developer.apple.com',
  'youtube.com',
  'youtu.be',
  'github.com',
  'twitter.com',
  'x.com',
  'instagram.com',
  'facebook.com',
  'linkedin.com',
  'medium.com',
  'news.ycombinator.com',
  'reddit.com',
];

export const isAppleFriendlyURL = url => {
  try {
    const urlObj = new URL(url);
    const domain = urlObj.hostname.replace('www.', '');
    return APPLE_FRIENDLY_DOMAINS.some(
      friendlyDomain =>
        domain === friendlyDomain || domain.endsWith(`.${friendlyDomain}`)
    );
  } catch {
    return false;
  }
};

export const getRichLinkRecommendation = url => {
  if (isAppleFriendlyURL(url)) {
    return {
      recommended: true,
      reason: 'This URL is known to work well with Apple Messages Rich Links',
      confidence: 'high',
    };
  }

  return {
    recommended: true,
    reason: 'Rich Links provide better user experience than plain URLs',
    confidence: 'medium',
  };
};
