<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, no-alert -->
<script setup>
import { ref } from 'vue';
import HandlerMethodsBrowser from './HandlerMethodsBrowser.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Example bot ID (replace with actual bot ID)
const botId = ref(1);

// Reference to the browser component
const browserRef = ref(null);

/**
 * Handle handler selection
 */
function handleHandlerSelected(handler) {
  // eslint-disable-next-line no-console
  console.log('Selected handler:', handler);

  // Example: Update a state node with the selected handler
  // nodeData.handlerMethod = handler.method_name;

  // Example: Display handler info
  alert(`Selected: ${handler.display_name}\nMethod: ${handler.method_name}`);
}

/**
 * Open the browser
 */
function openBrowser() {
  browserRef.value?.open();
}
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <div class="p-8">
    <h1 class="text-2xl font-bold mb-4">Handler Methods Browser Example</h1>

    <p class="text-n-slate-11 mb-6">
      Click the button below to open the handler methods browser modal.
    </p>

    <!-- Trigger Button -->
    <Button
      label="Browse Handler Methods"
      icon="i-lucide-search"
      @click="openBrowser"
    />

    <!-- Handler Methods Browser -->
    <HandlerMethodsBrowser
      ref="browserRef"
      :bot-id="botId"
      service-name="AcousticHouseBotService"
      @handler-selected="handleHandlerSelected"
    />
  </div>
</template>
