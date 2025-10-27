<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AppleMessagesComposer from './conversation/ReplyBox/AppleMessagesComposer.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['sendAppleMessage']);

const showAppleComposer = ref(false);

const currentChat = useMapGetter('getSelectedChat');

const isAppleMessagesChannel = computed(() => {
  return props.inbox?.channel_type === 'Channel::AppleMessagesForBusiness';
});

const handleSendAppleMessage = messageData => {
  emit('sendAppleMessage', messageData);
  showAppleComposer.value = false;
};

const toggleAppleComposer = () => {
  showAppleComposer.value = !showAppleComposer.value;
};
</script>

<template>
  <div v-if="isAppleMessagesChannel" class="relative">
    <NextButton
      v-tooltip.top-end="'Apple Messages'"
      icon="i-ph-device-mobile"
      slate
      faded
      sm
      @click="toggleAppleComposer"
    >
      Apple Messages
    </NextButton>

    <!-- Apple Messages Composer Modal - Direct Access -->
    <div
      v-if="showAppleComposer"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
      @click.self="showAppleComposer = false"
    >
      <div
        class="bg-n-solid-1 dark:bg-n-slate-2 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto"
      >
        <div
          class="flex items-center justify-between p-4 border-b border-n-weak dark:border-n-slate-6"
        >
          <h3
            class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Apple Messages for Business
          </h3>
          <NextButton
            icon="i-ph-x"
            slate
            faded
            sm
            @click="showAppleComposer = false"
          />
        </div>

        <div class="p-4">
          <AppleMessagesComposer
            :conversation="currentChat"
            @send="handleSendAppleMessage"
            @cancel="showAppleComposer = false"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  backdrop-filter: blur(4px);
}
</style>
