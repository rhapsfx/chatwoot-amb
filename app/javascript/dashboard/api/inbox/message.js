/* eslint no-console: 0 */
/* global axios */
import ApiClient from '../ApiClient';

export const buildCreatePayload = ({
  message,
  isPrivate,
  contentAttributes,
  contentType,
  echoId,
  files,
  ccEmails = '',
  bccEmails = '',
  toEmails = '',
  templateParams,
  templateId,
  isVoiceMessage = false,
}) => {
  let payload;
  if (files && files.length !== 0) {
    payload = new FormData();
    if (message) {
      payload.append('content', message);
    }
    files.forEach(file => {
      payload.append('attachments[]', file);
    });
    payload.append('private', isPrivate);
    payload.append('echo_id', echoId);
    payload.append('cc_emails', ccEmails);
    payload.append('bcc_emails', bccEmails);

    if (toEmails) {
      payload.append('to_emails', toEmails);
    }
    if (contentAttributes) {
      console.log(
        '🔥 buildCreatePayload: Serializing content_attributes for FormData:',
        contentAttributes
      );
      console.log(
        '🔥 buildCreatePayload: Images in content_attributes:',
        contentAttributes.images?.length || 'NO IMAGES'
      );

      // Sanitize contentAttributes to remove undefined values before serialization
      // This prevents JavaScript undefined from being serialized as the string "undefined"
      const sanitizeObject = obj => {
        if (Array.isArray(obj)) {
          return obj
            .map(item => sanitizeObject(item))
            .filter(item => item !== undefined);
        }
        if (obj && typeof obj === 'object') {
          return Object.fromEntries(
            Object.entries(obj)
              .filter(([, value]) => value !== undefined)
              .map(([key, value]) => [key, sanitizeObject(value)])
          );
        }
        return obj;
      };

      const sanitizedContentAttributes = sanitizeObject(contentAttributes);
      const serializedContentAttributes = JSON.stringify(
        sanitizedContentAttributes
      );
      console.log(
        '🔥 buildCreatePayload: Serialized content_attributes length:',
        serializedContentAttributes.length
      );
      payload.append('content_attributes', serializedContentAttributes);
    }
    if (isVoiceMessage) {
      payload.append('is_voice_message', true);
    }
    if (contentType) {
      payload.append('content_type', contentType);
    }
    if (templateId) {
      payload.append('template_id', templateId);
    }
  } else {
    // Sanitize contentAttributes for regular JSON payloads too
    const sanitizeObject = obj => {
      if (Array.isArray(obj)) {
        return obj
          .map(item => sanitizeObject(item))
          .filter(item => item !== undefined);
      }
      if (obj && typeof obj === 'object') {
        return Object.fromEntries(
          Object.entries(obj)
            .filter(([, value]) => value !== undefined)
            .map(([key, value]) => [key, sanitizeObject(value)])
        );
      }
      return obj;
    };

    const sanitizedContentAttributes = contentAttributes
      ? sanitizeObject(contentAttributes)
      : undefined;

    payload = {
      content: message,
      private: isPrivate,
      echo_id: echoId,
      content_attributes: sanitizedContentAttributes,
      content_type: contentType,
      cc_emails: ccEmails,
      bcc_emails: bccEmails,
      to_emails: toEmails,
      template_params: templateParams,
      template_id: templateId,
    };
  }
  return payload;
};

class MessageApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  create(params) {
    console.log('🔥 MessageApi.create called with params:', params);

    // Handle both camelCase and snake_case property names
    const {
      conversationId,
      message,
      private: isPrivate,
      contentAttributes,
      content_attributes,
      content_type,
      echo_id: echoId,
      files,
      ccEmails = '',
      bccEmails = '',
      toEmails = '',
      templateParams,
      template_id: templateId,
      isVoiceMessage = false,
    } = params;

    console.log(
      '🔥 MessageApi extracted content_attributes:',
      content_attributes
    );
    console.log(
      '🔥 MessageApi extracted contentAttributes:',
      contentAttributes
    );
    console.log('🔥 MessageApi extracted template_id:', templateId);

    // Use content_attributes if contentAttributes is not provided (for Vuex compatibility)
    const finalContentAttributes = contentAttributes || content_attributes;
    const finalContentType = content_type;
    const finalEchoId = echoId || params.echo_id;
    const finalTemplateId = templateId || params.template_id;

    console.log(
      '🔥 MessageApi finalContentAttributes:',
      finalContentAttributes
    );
    console.log(
      '🔥 MessageApi finalContentAttributes images:',
      finalContentAttributes?.images?.length || 'NO IMAGES'
    );
    console.log('🔥 MessageApi finalTemplateId:', finalTemplateId);

    const payload = buildCreatePayload({
      message,
      isPrivate,
      contentAttributes: finalContentAttributes,
      contentType: finalContentType,
      echoId: finalEchoId,
      files,
      ccEmails,
      bccEmails,
      toEmails,
      templateParams,
      templateId: finalTemplateId,
      isVoiceMessage,
    });

    console.log('🔥 MessageApi final payload:', payload);
    console.log(
      '🔥 MessageApi payload content_attributes:',
      payload.content_attributes
    );
    console.log(
      '🔥 MessageApi payload images:',
      payload.content_attributes?.images?.length || 'NO IMAGES'
    );
    console.log('🔥 MessageApi payload template_id:', payload.template_id);

    return axios({
      method: 'post',
      url: `${this.url}/${conversationId}/messages`,
      data: payload,
    });
  }

  delete(conversationID, messageId) {
    return axios.delete(`${this.url}/${conversationID}/messages/${messageId}`);
  }

  retry(conversationID, messageId) {
    return axios.post(
      `${this.url}/${conversationID}/messages/${messageId}/retry`
    );
  }

  getPreviousMessages({ conversationId, after, before }) {
    const params = { before };
    if (after && Number(after) !== Number(before)) {
      params.after = after;
    }
    return axios.get(`${this.url}/${conversationId}/messages`, { params });
  }

  translateMessage(conversationId, messageId, targetLanguage) {
    return axios.post(
      `${this.url}/${conversationId}/messages/${messageId}/translate`,
      {
        target_language: targetLanguage,
      }
    );
  }
}

export default new MessageApi();
