import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';

/**
 * Composable for bot flow simulation
 * Provides real-time testing of bot flows with execution tracking
 *
 * @param {Number} botId - Bot ID
 * @param {Number} flowId - Flow ID
 * @returns {Object} Simulator interface
 */
export function useBotSimulator(botId, flowId) {
  const store = useStore();
  const messages = ref([]);
  const executedNodes = ref([]);
  const currentState = ref('');
  const session = ref({});
  const isProcessing = ref(false);

  /**
   * Reset simulation state
   */
  const reset = () => {
    messages.value = [];
    executedNodes.value = [];
    currentState.value = '';
    session.value = {};
  };

  /**
   * Send user message and get bot response
   * @param {String} text - User message text
   */
  const sendMessage = async text => {
    if (!text || isProcessing.value) return;

    isProcessing.value = true;

    // Add user message
    messages.value.push({
      sender: 'user',
      text,
      time: new Date(),
    });

    try {
      // Call simulation API
      const result = await store.dispatch('agentBots/simulateFlow', {
        botId,
        flowId,
        message: text,
        session: session.value,
      });

      if (result) {
        // Update session state
        session.value = result.session || {};
        currentState.value = result.current_state || '';
        executedNodes.value = result.executed_nodes || [];

        // Add bot response
        messages.value.push({
          sender: 'bot',
          text: result.bot_response || 'No response',
          time: new Date(),
          templatePreviews: result.template_previews || [],
          metadata: {
            state: result.current_state,
            executedNodes: result.executed_nodes,
          },
        });
      } else {
        // Error fallback
        messages.value.push({
          sender: 'bot',
          text: 'Failed to process message',
          time: new Date(),
          error: true,
        });
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('[BotSimulator] Error:', error);
      messages.value.push({
        sender: 'bot',
        text: `Error: ${error.message || 'Unknown error'}`,
        time: new Date(),
        error: true,
      });
    } finally {
      isProcessing.value = false;
    }
  };

  return {
    messages,
    executedNodes,
    currentState,
    session,
    isProcessing,
    reset,
    sendMessage,
  };
}
