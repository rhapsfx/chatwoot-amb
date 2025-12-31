<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  botId: {
    type: Number,
    required: false,
    default: null,
  },
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();

const store = useStore();

// Local editable state
const editedData = ref({
  template_name: '',
  template_type: 'list_picker',
});

// Fetch templates from store
const templates = computed(
  () => store.getters['messageTemplates/getTemplates'] || []
);
const isLoadingTemplates = computed(
  () => store.getters['messageTemplates/getUIFlags'].isFetching
);

// Filter templates by channel (Apple Messages for Business)
const ambTemplates = computed(() => {
  const filtered = templates.value.filter(template => {
    // Check supported_channels array for apple_messages_for_business
    const supportedChannels =
      template.supportedChannels || template.supported_channels || [];
    const hasAMBChannel = supportedChannels.includes(
      'apple_messages_for_business'
    );

    // Also check channel_mappings for backward compatibility
    const channelMappings =
      template.channelMappings || template.channel_mappings || [];
    const hasAMBMapping = channelMappings.some(
      cm =>
        cm.channel_type === 'Channel::AppleMessagesForBusiness' ||
        cm.channelType === 'Channel::AppleMessagesForBusiness'
    );

    return hasAMBChannel || hasAMBMapping;
  });

  return filtered;
});

// Group templates by type
const templatesByType = computed(() => {
  const grouped = {
    list_picker: [],
    time_picker: [],
    form: [],
    rich_link: [],
    apple_pay: [],
  };

  ambTemplates.value.forEach(template => {
    // Try to determine template type from various sources
    let blockType = null;

    // 1. Try content_blocks or contentBlocks
    const contentBlocks =
      template.contentBlocks || template.content_blocks || [];
    if (contentBlocks.length > 0) {
      blockType = contentBlocks[0].blockType || contentBlocks[0].block_type;
    }

    // 2. Try metadata
    if (!blockType && template.metadata) {
      const content = template.metadata.apple_message_content || {};
      const attrs = content.content_attributes || {};

      if (attrs.sections) blockType = 'list_picker';
      else if (attrs.event || attrs.time_picker) blockType = 'time_picker';
      else if (attrs.pages || attrs.form) blockType = 'form';
      else if (attrs.rich_link) blockType = 'rich_link';
      else if (attrs.apple_pay) blockType = 'apple_pay';
    }

    // 3. Try to infer from template name
    if (!blockType) {
      const name = template.name.toLowerCase();
      if (name.includes('list') || name.includes('menu'))
        blockType = 'list_picker';
      else if (name.includes('time') || name.includes('calendar'))
        blockType = 'time_picker';
      else if (name.includes('form')) blockType = 'form';
    }

    // Add to appropriate group
    if (blockType && grouped[blockType]) {
      grouped[blockType].push(template);
    }
  });

  return grouped;
});

// Get templates for current type
const availableTemplates = computed(() => {
  return templatesByType.value[editedData.value.template_type] || [];
});

// Initialize with node data
watch(
  () => props.node,
  newNode => {
    if (newNode?.data) {
      editedData.value = {
        template_name: newNode.data.template_name || '',
        template_type: newNode.data.template_type || 'list_picker',
      };
    }
  },
  { immediate: true }
);

// Fetch templates on mount
onMounted(async () => {
  try {
    await store.dispatch('messageTemplates/get', {
      channel: 'apple_messages_for_business',
      per_page: 100, // Get more templates
    });
  } catch (error) {
    // Error fetching templates
  }
});

const handleSave = () => {
  emit('save', editedData.value);
};

const handleCancel = () => {
  emit('cancel');
};
</script>

<template>
  <div class="template-node-editor">
    <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
      {{ t('AGENT_BOTS.EDITORS.EDIT_TEMPLATE_NODE') }}
    </h3>

    <div class="space-y-4">
      <!-- Template Type -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.TEMPLATE_TYPE') }}
        </label>
        <select
          v-model="editedData.template_type"
          class="w-full px-3 py-2 pr-8 border border-n-strong rounded-md bg-n-white text-n-slate-12 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 16 16%27 fill=%27%23666%27%3E%3Cpath d=%27M4.5 5.5l3.5 3.5 3.5-3.5h-7z%27/%3E%3C/svg%3E')] bg-[length:0.875rem] bg-[right_0.5rem_center] bg-no-repeat"
        >
          <option value="list_picker">
            {{ t('AGENT_BOTS.EDITORS.LIST_PICKER') }}
          </option>
          <option value="time_picker">
            {{ t('AGENT_BOTS.EDITORS.TIME_PICKER') }}
          </option>
          <option value="form">{{ t('AGENT_BOTS.EDITORS.FORM') }}</option>
          <option value="rich_link">
            {{ t('AGENT_BOTS.EDITORS.RICH_LINK') }}
          </option>
          <option value="apple_pay">
            {{ t('AGENT_BOTS.EDITORS.APPLE_PAY') }}
          </option>
        </select>
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.TEMPLATE_TYPE_HELP') }}
        </p>
      </div>

      <!-- Template Name Dropdown -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.TEMPLATE_NAME') }}
        </label>

        <!-- Loading state -->
        <div v-if="isLoadingTemplates" class="text-sm text-n-slate-10 py-2">
          {{ t('AGENT_BOTS.NODE_CONFIG.LOADING_TEMPLATES') }}
        </div>

        <!-- Template dropdown -->
        <select
          v-else-if="availableTemplates.length > 0"
          v-model="editedData.template_name"
          class="w-full px-3 py-2 pr-8 border border-n-strong rounded-md bg-n-white text-n-slate-12 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 16 16%27 fill=%27%23666%27%3E%3Cpath d=%27M4.5 5.5l3.5 3.5 3.5-3.5h-7z%27/%3E%3C/svg%3E')] bg-[length:0.875rem] bg-[right_0.5rem_center] bg-no-repeat"
        >
          <option value="">
            {{ t('AGENT_BOTS.EDITORS.SELECT_TEMPLATE') }}
          </option>
          <option
            v-for="template in availableTemplates"
            :key="template.id"
            :value="template.name"
          >
            {{
              template.description
                ? `${template.name} - ${template.description}`
                : template.name
            }}
          </option>
        </select>

        <!-- Fallback to text input if no templates -->
        <div v-else>
          <Input
            v-model="editedData.template_name"
            placeholder="e.g., ah_guitar_info_form"
            class="w-full"
          />
          <p class="text-xs text-n-amber-11 mt-1">
            {{
              t('AGENT_BOTS.EDITORS.NO_TEMPLATES_FOUND', {
                type: editedData.template_type,
              })
            }}
          </p>
        </div>

        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.TEMPLATE_NAME_HELP') }}
        </p>
      </div>

      <!-- Save/Cancel Buttons -->
      <div class="flex gap-2 pt-4 border-t border-n-strong">
        <Button
          variant="primary"
          icon="i-lucide-save"
          class="flex-1"
          @click="handleSave"
        >
          {{ t('AGENT_BOTS.EDITORS.SAVE_CHANGES') }}
        </Button>
        <Button
          variant="slate"
          icon="i-lucide-x"
          class="flex-1"
          @click="handleCancel"
        >
          {{ t('AGENT_BOTS.EDITORS.CANCEL') }}
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.template-node-editor {
  padding: 0;
}
</style>
