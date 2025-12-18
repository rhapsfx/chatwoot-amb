<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useBotSimulator } from '../composables/useBotSimulator';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  botId: { type: Number, required: true },
  flowId: { type: Number, default: null },
  flowName: { type: String, default: 'Bot Flow' },
});

const emit = defineEmits(['nodeExecuted']);

const { t } = useI18n();
const input = ref('');
const simulator = ref(null);

// Initialize simulator when flowId changes
watch(
  () => props.flowId,
  newFlowId => {
    if (newFlowId && props.botId) {
      simulator.value = useBotSimulator(props.botId, newFlowId);
    }
  },
  { immediate: true }
);

const canSend = computed(() => {
  return (
    input.value.trim() && simulator.value && !simulator.value.isProcessing.value
  );
});

const send = async () => {
  if (!canSend.value) return;

  await simulator.value.sendMessage(input.value);
  input.value = '';

  // Emit executed nodes for canvas highlighting
  if (simulator.value.executedNodes.value.length > 0) {
    emit('nodeExecuted', simulator.value.executedNodes.value);
  }
};

const handleReset = () => {
  if (simulator.value) {
    simulator.value.reset();
    emit('nodeExecuted', []);
  }
};
</script>

<template>
  <div class="flex flex-col h-full bg-n-white">
    <!-- Header -->
    <div
      class="px-4 py-3 border-b border-n-soft flex items-center justify-between"
    >
      <div>
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('AGENT_BOTS.TEST_CONSOLE.TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11">{{ flowName }}</p>
      </div>
      <button
        class="flex items-center gap-1.5 px-2 py-1 text-xs text-n-slate-11 hover:text-n-slate-12 hover:bg-n-slate-3 rounded transition-colors"
        :title="t('AGENT_BOTS.TEST_CONSOLE.RESET')"
        @click="handleReset"
      >
        <i class="i-lucide-rotate-ccw w-3 h-3" />
        {{ t('AGENT_BOTS.TEST_CONSOLE.RESET') }}
      </button>
    </div>

    <!-- Messages Area -->
    <div class="flex-1 overflow-y-auto p-4 space-y-3">
      <!-- Empty State -->
      <div
        v-if="!simulator || simulator.messages.value.length === 0"
        class="flex flex-col items-center justify-center h-full text-center text-n-slate-11"
      >
        <i class="i-lucide-bot w-12 h-12 mb-3 text-n-slate-9" />
        <p class="text-sm mb-1">
          {{ t('AGENT_BOTS.TEST_CONSOLE.EMPTY_STATE') }}
        </p>
        <p class="text-xs text-n-slate-10">
          {{ t('AGENT_BOTS.TEST_CONSOLE.EMPTY_HINT') }}
        </p>
      </div>

      <!-- Messages -->
      <div
        v-for="(msg, i) in simulator?.messages.value || []"
        :key="i"
        class="flex"
        :class="msg.sender === 'user' ? 'justify-end' : 'justify-start'"
      >
        <div class="max-w-[80%] flex flex-col">
          <!-- Message Bubble -->
          <div
            class="rounded-lg px-3 py-2 text-sm break-words"
            :class="[
              msg.sender === 'user'
                ? 'bg-n-blue-9 text-white'
                : msg.error
                  ? 'bg-n-red-3 text-n-red-11 border border-n-red-6'
                  : 'bg-n-slate-3 text-n-slate-12',
            ]"
          >
            <div class="whitespace-pre-wrap">{{ msg.text }}</div>
          </div>

          <!-- Metadata (for bot messages) -->
          <div
            v-if="msg.sender === 'bot' && msg.metadata && !msg.error"
            class="mt-1 px-2 text-xs text-n-slate-10"
          >
            <div v-if="msg.metadata.state" class="flex items-center gap-1">
              <i class="i-lucide-circle-dot w-3 h-3" />
              <span
                >{{ t('AGENT_BOTS.TEST_CONSOLE.STATE_LABEL') }}:
                {{ msg.metadata.state }}</span
              >
            </div>
            <div
              v-if="msg.metadata.executedNodes?.length > 0"
              class="flex items-center gap-1 mt-0.5"
            >
              <i class="i-lucide-workflow w-3 h-3" />
              <span>{{
                t('AGENT_BOTS.TEST_CONSOLE.EXECUTED_NODES', {
                  count: msg.metadata.executedNodes.length,
                })
              }}</span>
            </div>
          </div>

          <!-- Timestamp -->
          <div
            class="mt-1 px-2 text-xs text-n-slate-9"
            :class="msg.sender === 'user' ? 'text-right' : 'text-left'"
          >
            {{ msg.time.toLocaleTimeString() }}
          </div>
        </div>
      </div>

      <!-- Processing indicator -->
      <div v-if="simulator?.isProcessing.value" class="flex justify-start">
        <div class="bg-n-slate-3 rounded-lg px-3 py-2 flex items-center gap-2">
          <div class="flex gap-1">
            <span
              class="w-2 h-2 bg-n-slate-9 rounded-full animate-bounce [animation-delay:0s]"
            />
            <span
              class="w-2 h-2 bg-n-slate-9 rounded-full animate-bounce [animation-delay:0.1s]"
            />
            <span
              class="w-2 h-2 bg-n-slate-9 rounded-full animate-bounce [animation-delay:0.2s]"
            />
          </div>
          <span class="text-xs text-n-slate-11">{{
            t('AGENT_BOTS.TEST_CONSOLE.PROCESSING')
          }}</span>
        </div>
      </div>
    </div>

    <!-- Current State Display -->
    <div
      v-if="simulator?.currentState.value"
      class="px-4 py-2 border-t border-n-soft bg-n-slate-1"
    >
      <div class="flex items-center gap-2 text-xs text-n-slate-11">
        <i class="i-lucide-circle-dot w-3 h-3" />
        <span>
          {{ t('AGENT_BOTS.TEST_CONSOLE.CURRENT_STATE') }}:
          <strong class="text-n-slate-12">{{
            simulator.currentState.value
          }}</strong>
        </span>
      </div>
    </div>

    <!-- Input Area -->
    <div class="p-4 border-t border-n-soft">
      <div class="flex gap-2">
        <input
          v-model="input"
          type="text"
          :placeholder="t('AGENT_BOTS.TEST_CONSOLE.INPUT_PLACEHOLDER')"
          :disabled="!simulator || simulator.isProcessing.value"
          class="flex-1 px-3 py-2 text-sm border border-n-soft rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent disabled:bg-n-slate-2 disabled:cursor-not-allowed"
          @keyup.enter="send"
        />
        <Button
          icon="i-lucide-send"
          :disabled="!canSend"
          :is-loading="simulator?.isProcessing.value"
          @click="send"
        >
          {{ t('AGENT_BOTS.TEST_CONSOLE.SEND') }}
        </Button>
      </div>
    </div>
  </div>
</template>
