// Apple Messages Rich Link Helper
// Automatic URL detection and Rich Link conversion for Apple Messages conversations

import ConstructPayloadAPI from '../api/appleMessages/constructPayload';
import ParseUrlAPI from '../api/appleMessages/parseUrl';

// Enhanced URL regex that detects URLs with and without protocol
// Supports multi-level domains (e.g., maps.apple.com) and complex paths with query params
// Path matching includes all RFC 3986 URL-safe characters: unreserved + reserved + percent-encoding
export const URL_REGEX =
  /(?:https?:\/\/)?(?:www\.)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[a-zA-Z0-9\-._~:/?#@!$&'()*+,;=%]+)?/gi;

// The rich-text editor's markdown serializer emits `[displayText](href)` for a hyperlink
// whenever its visible text differs from its href (e.g. a clean display URL behind a
// UTM/gclid-tracked href), and separately backslash-escapes markdown-special characters like
// `_` inside the href. Left alone, this breaks URL detection two ways: the escape sequence
// truncates the regex match mid-URL, and the bracketed display text (itself often a duplicate,
// shorter URL) gets detected as a second, separate link. Unwrap to the real href before
// anything else runs.
const MARKDOWN_LINK_REGEX = /\[([^\]]*)\]\(([^\s)]+)\)/g;

export const unwrapMarkdownLinks = text => {
  if (!text || typeof text !== 'string') return text;

  return text.replace(MARKDOWN_LINK_REGEX, (match, linkText, href) => {
    const unescapedHref = href.replace(/\\([\\`*_{}[\]()#+\-.!])/g, '$1');
    const trimmedLinkText = linkText.trim();

    // Display text is just the href (or a prefix of it) — the serializer's redundant echo,
    // not real message content, so drop it and keep only the real URL.
    if (
      !trimmedLinkText ||
      unescapedHref === trimmedLinkText ||
      unescapedHref.startsWith(trimmedLinkText)
    ) {
      return unescapedHref;
    }

    return `${trimmedLinkText} ${unescapedHref}`;
  });
};

// Preprocess text to join URLs split across lines
// This handles cases where users copy-paste URLs that get line-wrapped
export const preprocessTextForURLDetection = text => {
  if (!text || typeof text !== 'string') return text;

  // Remove all line breaks and extra whitespace within URLs
  // This aggressively joins any URL fragments
  let processed = unwrapMarkdownLinks(text);

  // First pass: Join URL parts split mid-domain (e.g., "maps.apple" + ".com/path")
  // This handles cases where the TLD is separated from the domain name
  processed = processed.replace(
    /(https?:\/\/[a-zA-Z0-9-]+)([\s\n]+)(\.[a-zA-Z]{2,}[^\s]*)/g,
    '$1$3'
  );

  // Second pass: Join protocol/domain with path on next line
  // Example: "https://maps.apple.com" + "\n/place?..." -> "https://maps.apple.com/place?..."
  processed = processed.replace(
    /(https?:\/\/[a-zA-Z0-9-]+\.[a-zA-Z]{2,})([\s\n]+)(\/[^\s]*)/g,
    '$1$3'
  );

  // Third pass: Join URL fragments that start with query params or path segments
  // Example: "https://example.com" + "\n?param=value" -> "https://example.com?param=value"
  processed = processed.replace(
    /(https?:\/\/[^\s]+)([\s\n]+)([?&/][^\s]*)/g,
    '$1$3'
  );

  // Fourth pass: Join any remaining URL-like fragments
  // Pattern: URL-like text followed by whitespace followed by URL continuation
  processed = processed.replace(
    /(https?:\/\/[^\s]+)\s+([a-zA-Z0-9/_\-.?&=+%]+)/g,
    (match, part1, part2) => {
      // Only join if part2 looks like a URL path/query continuation
      if (/^[a-zA-Z0-9/_\-.?&=+%]/.test(part2) && !part2.includes(' ')) {
        return `${part1}${part2}`;
      }
      return match;
    }
  );

  // Fifth pass: Handle domains followed by paths on new lines
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
    let matchStart = match.index;
    let matchEnd = match.index + match[0].length;

    // Autolink-style wrapping (`<https://example.com>`) is a common rich-text-editor/markdown
    // convention for delimiting a bare URL. URL_REGEX correctly excludes `<`/`>` from the URL
    // itself, but without this the leftover bracket becomes its own throwaway "<" / ">" message
    // bubble. Treat adjacent brackets as delimiters, not message text.
    if (matchStart > 0 && processedText[matchStart - 1] === '<') {
      matchStart -= 1;
    }
    if (processedText[matchEnd] === '>') {
      matchEnd += 1;
    }

    // Add text before URL if exists
    if (matchStart > lastIndex) {
      const beforeText = processedText.slice(lastIndex, matchStart).trim();
      if (beforeText) {
        parts.push({ type: 'text', content: beforeText });
      }
    }

    // Add URL as Rich Link (normalize URL first)
    parts.push({ type: 'url', content: normalizeURL(match[0]) });

    lastIndex = matchEnd;
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
  // - maps.apple.com/directions?... (directions URLs with source/destination)
  // - maps.apple.com/frame?... (frame URLs with parameters: center, span, distance, heading, pitch, map mode, tracking)
  // - maps.apple.com/?... (with query params)
  // - maps.apple/p/... (short URLs)
  // - maps.apple.com/place/... (place URLs)
  return (
    url.includes('maps.apple.com') ||
    url.includes('maps.apple/') ||
    /maps\.apple\.com\/directions\?/.test(url) ||
    /maps\.apple\.com\/frame\?/.test(url) ||
    /maps\.apple\.com\/\?/.test(url) ||
    /maps\.apple\.com\/place\//.test(url) ||
    /maps\.apple\/p\//.test(url)
  );
};

export const createRichLinkPreview = async (
  url,
  conversation = null,
  allowAppClips = false
) => {
  try {
    // Normalize URL before processing
    const normalizedURL = normalizeURL(url);

    // Get account ID from current URL path
    const accountId = window.location.pathname.match(/accounts\/(\d+)/)?.[1];
    if (!accountId) {
      throw new Error('Account ID not found');
    }

    // App Clips (constructPayload) is only attempted when explicitly requested via the modal.
    // Automatic URL-to-rich-link conversion always uses OpenGraph so the device renders the
    // preview immediately without showing "Click to Load Preview".
    const skipAppClips =
      !allowAppClips ||
      isDirectVideoURL(normalizedURL) ||
      isAppleMapsURL(normalizedURL);

    if (!skipAppClips && conversation?.inbox_id) {
      try {
        if (ConstructPayloadAPI.mightSupportAppClips(normalizedURL)) {
          const constructResult = await ConstructPayloadAPI.create(
            accountId,
            conversation.inbox_id,
            { url: normalizedURL, storeRegion: 'US' }
          );

          if (constructResult.success && constructResult.rich_link_data_ref) {
            return {
              success: true,
              isAppClips: true,
              richLinkData: {
                url: normalizedURL,
                rich_link_data_ref: constructResult.rich_link_data_ref,
              },
            };
          }
        }
      } catch (error) {
        // Construct Payload API failed, fall through to OpenGraph
      }
    }

    // Use OpenGraph scraping — embeds title/description/image in the payload so the
    // device renders the preview immediately without requiring the user to tap.
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
  conversation,
  cachedPreviewData = null
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
      // Use cached preview data if available (avoids a second parse_url API call on Enter)
      const richLinkPreview =
        cachedPreviewData && cachedPreviewData.url === urlPart.content
          ? {
              success: true,
              isAppClips: false,
              richLinkData: cachedPreviewData,
            }
          : await createRichLinkPreview(urlPart.content, conversation);

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
