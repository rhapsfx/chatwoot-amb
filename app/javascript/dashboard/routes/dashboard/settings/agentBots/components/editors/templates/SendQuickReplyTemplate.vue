<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const message = computed({
  get: () => props.modelValue.message || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, message: value }),
});

const requestId = computed({
  get: () => props.modelValue.request_id || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, request_id: value }),
});

const items = computed({
  get: () => props.modelValue.items || [],
  set: value =>
    emit('update:modelValue', { ...props.modelValue, items: value }),
});

const addItem = () => {
  const newItems = [...items.value, { title: '', value: '' }];
  emit('update:modelValue', { ...props.modelValue, items: newItems });
};

const removeItem = index => {
  const newItems = items.value.filter((_, i) => i !== index);
  emit('update:modelValue', { ...props.modelValue, items: newItems });
};

const updateItem = (index, field, value) => {
  const newItems = [...items.value];
  newItems[index] = { ...newItems[index], [field]: value };
  emit('update:modelValue', { ...props.modelValue, items: newItems });
};
</script>

<template>
  <div class="space-y-4">
    <!-- Message -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.MESSAGE'
          )
        }}
        *
      </label>
      <textarea
        v-model="message"
        rows="3"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.MESSAGE_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Request ID -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.REQUEST_ID'
          )
        }}
        *
      </label>
      <input
        v-model="requestId"
        type="text"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.REQUEST_ID_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.REQUEST_ID_HELP'
          )
        }}
      </p>
    </div>

    <!-- Items (Dynamic List) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.ITEMS'
          )
        }}
        *
      </label>

      <div
        v-if="items.length === 0"
        class="p-4 bg-n-slate-2 border border-n-weak rounded-lg text-center text-sm text-n-slate-11"
      >
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.NO_ITEMS'
          )
        }}
      </div>

      <div v-else class="space-y-2">
        <div
          v-for="(item, index) in items"
          :key="index"
          class="flex gap-2 items-start"
        >
          <input
            :value="item.title"
            type="text"
            class="flex-1 px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
            :placeholder="
              t(
                'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.ITEM_TITLE_PLACEHOLDER'
              )
            "
            @input="updateItem(index, 'title', $event.target.value)"
          />
          <input
            :value="item.value"
            type="text"
            class="flex-1 px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
            :placeholder="
              t(
                'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.ITEM_VALUE_PLACEHOLDER'
              )
            "
            @input="updateItem(index, 'value', $event.target.value)"
          />
          <button
            class="p-2 text-red-600 hover:bg-red-50 rounded transition-colors"
            :aria-label="
              t(
                'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.REMOVE_ITEM'
              )
            "
            @click="removeItem(index)"
          >
            <i class="i-lucide-trash-2 w-4 h-4" />
          </button>
        </div>
      </div>

      <button
        class="mt-2 px-4 py-2 bg-n-blue-8 text-white rounded-lg hover:bg-n-blue-9 transition-colors flex items-center gap-2"
        @click="addItem"
      >
        <i class="i-lucide-plus w-4 h-4" />
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_QUICK_REPLY.PARAMETERS.ADD_ITEM'
          )
        }}
      </button>
    </div>
  </div>
</template>
