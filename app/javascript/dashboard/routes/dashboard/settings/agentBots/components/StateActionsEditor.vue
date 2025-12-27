<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ActionTemplateEditor from './ActionTemplateEditor.vue';
import agentBotsAPI from 'dashboard/api/agentBots';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  botId: {
    type: Number,
    required: true,
  },
  accountId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

// Local state
const localActions = ref([...props.modelValue]);
const availableTemplates = ref([]);
const loadingTemplates = ref(false);
const loadError = ref(null);
const expandedTemplates = ref([]);
const templateEditorRef = ref(null);
const editingTemplate = ref(null);

// Computed
const hasActions = computed(() => localActions.value.length > 0);

// Template options for dropdown
const templateOptions = computed(() => {
  return availableTemplates.value.map(template => ({
    value: template.id,
    label: `${template.name} (${template.template_type})`,
    description:
      template.parameters?.message || template.parameters?.title || '',
  }));
});

// Action type options
const actionTypeOptions = [
  {
    value: 'execute_template',
    label: 'Execute Template',
    description: 'Execute a single template',
  },
  {
    value: 'execute_templates',
    label: 'Execute Multiple Templates',
    description: 'Execute multiple templates in sequence',
  },
];

// Load available BotActionTemplates
const loadTemplates = async () => {
  loadingTemplates.value = true;
  loadError.value = null;

  try {
    const response = await agentBotsAPI.getBotActionTemplates(
      props.accountId,
      props.botId
    );
    availableTemplates.value = response.data.templates || [];
  } catch (error) {
    // Error loading templates
    loadError.value = error.message || 'Failed to load templates';
    availableTemplates.value = [];
  } finally {
    loadingTemplates.value = false;
  }
};

// Emit updates to parent
const emitUpdate = () => {
  emit('update:modelValue', localActions.value);
};

// Add new action
const addAction = () => {
  const newAction = {
    type: 'execute_template',
    template_id: null,
  };
  localActions.value.push(newAction);
  emitUpdate();
};

// Remove action
const removeAction = index => {
  localActions.value.splice(index, 1);
  emitUpdate();
};

// Move action up
const moveActionUp = index => {
  if (index > 0) {
    const temp = localActions.value[index];
    localActions.value[index] = localActions.value[index - 1];
    localActions.value[index - 1] = temp;
    emitUpdate();
  }
};

// Move action down
const moveActionDown = index => {
  if (index < localActions.value.length - 1) {
    const temp = localActions.value[index];
    localActions.value[index] = localActions.value[index + 1];
    localActions.value[index + 1] = temp;
    emitUpdate();
  }
};

// Get template details by ID
const getTemplateDetails = templateId => {
  return availableTemplates.value.find(tmpl => tmpl.id === templateId);
};

// Handle action type change
const onActionTypeChange = index => {
  const action = localActions.value[index];
  if (action.type === 'execute_template') {
    // Single template - use template_id
    delete action.template_ids;
    if (!action.template_id) {
      action.template_id = null;
    }
  } else if (action.type === 'execute_templates') {
    // Multiple templates - use template_ids array
    delete action.template_id;
    if (!action.template_ids) {
      action.template_ids = [];
    }
  }
  emitUpdate();
};

// Handle template selection for single template
const onTemplateSelect = (index, templateId) => {
  localActions.value[index].template_id = templateId;
  emitUpdate();
};

// Add template to template_ids array
const addTemplateToArray = index => {
  const action = localActions.value[index];
  if (!action.template_ids) {
    action.template_ids = [];
  }
  action.template_ids.push(null);
  emitUpdate();
};

// Remove template from template_ids array
const removeTemplateFromArray = (actionIndex, templateIndex) => {
  const action = localActions.value[actionIndex];
  action.template_ids.splice(templateIndex, 1);
  emitUpdate();
};

// Update template in template_ids array
const updateTemplateInArray = (actionIndex, templateIndex, templateId) => {
  const action = localActions.value[actionIndex];
  action.template_ids[templateIndex] = templateId;
  emitUpdate();
};

// Toggle template details expansion
const toggleTemplateDetails = templateId => {
  const index = expandedTemplates.value.indexOf(templateId);
  if (index > -1) {
    expandedTemplates.value.splice(index, 1);
  } else {
    expandedTemplates.value.push(templateId);
  }
};

// Edit template
const editTemplate = async templateId => {
  const template = getTemplateDetails(templateId);
  if (template) {
    editingTemplate.value = { ...template };
    await nextTick();
    templateEditorRef.value?.open();
  }
};

// Handle template save from editor
const handleTemplateSave = async templateData => {
  try {
    const response = await agentBotsAPI.updateBotActionTemplate(
      props.botId,
      editingTemplate.value.id,
      templateData
    );

    // Update template in availableTemplates list
    const index = availableTemplates.value.findIndex(
      tmpl => tmpl.id === editingTemplate.value.id
    );
    if (index > -1) {
      availableTemplates.value[index] = response.data.template;
    }

    // Close editor
    templateEditorRef.value?.close();
    editingTemplate.value = null;

    // Show success notification would go here if we had a notification system
  } catch (error) {
    // Error handling - could show error notification here
  }
};

// Initialize
onMounted(() => {
  loadTemplates();
});
</script>

<template>
  <div class="state-actions-editor">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('AGENT_BOTS.NODE_CONFIG.ACTIONS') }}
        </h4>
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.NODE_CONFIG.ACTIONS_HELP') }}
        </p>
      </div>
      <Button
        v-if="!loadingTemplates"
        variant="primary"
        icon="i-lucide-plus"
        size="sm"
        @click="addAction"
      >
        {{ t('AGENT_BOTS.NODE_CONFIG.ADD_ACTION') }}
      </Button>
    </div>

    <!-- Loading State -->
    <div v-if="loadingTemplates" class="flex items-center justify-center py-8">
      <Spinner :size="32" />
      <span class="ml-2 text-sm text-n-slate-10">
        {{ t('AGENT_BOTS.NODE_CONFIG.LOADING_TEMPLATES') }}
      </span>
    </div>

    <!-- Error State -->
    <div
      v-else-if="loadError"
      class="p-4 bg-n-red-2 border border-n-red-6 rounded-lg"
    >
      <div class="flex items-center gap-2 text-n-red-11">
        <i class="i-lucide-alert-circle text-lg" />
        <span class="text-sm font-medium">{{ loadError }}</span>
      </div>
      <Button variant="slate" size="sm" class="mt-2" @click="loadTemplates">
        {{ t('AGENT_BOTS.NODE_CONFIG.RETRY') }}
      </Button>
    </div>

    <!-- Actions List -->
    <div v-else-if="hasActions" class="space-y-3">
      <div
        v-for="(action, actionIndex) in localActions"
        :key="`action-${actionIndex}`"
        class="p-4 bg-n-slate-2 border border-n-weak rounded-lg"
      >
        <!-- Action Header -->
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-2">
            <i class="i-lucide-zap text-n-slate-10" />
            <span class="text-sm font-medium text-n-slate-12">
              {{
                t('AGENT_BOTS.NODE_CONFIG.ACTION_NUMBER', {
                  number: actionIndex + 1,
                })
              }}
            </span>
          </div>
          <div class="flex items-center gap-1">
            <Button
              v-if="actionIndex > 0"
              variant="slate"
              icon="i-lucide-arrow-up"
              size="xs"
              @click="moveActionUp(actionIndex)"
            />
            <Button
              v-if="actionIndex < localActions.length - 1"
              variant="slate"
              icon="i-lucide-arrow-down"
              size="xs"
              @click="moveActionDown(actionIndex)"
            />
            <Button
              variant="slate"
              icon="i-lucide-trash-2"
              size="xs"
              @click="removeAction(actionIndex)"
            />
          </div>
        </div>

        <!-- Action Type Selector -->
        <div class="mb-3">
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            {{ t('AGENT_BOTS.NODE_CONFIG.ACTION_TYPE') }}
          </label>
          <select
            v-model="action.type"
            class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-white focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent text-n-slate-12"
            @change="onActionTypeChange(actionIndex)"
          >
            <option value="" disabled>
              {{ t('AGENT_BOTS.NODE_CONFIG.SELECT_ACTION_TYPE') }}
            </option>
            <option
              v-for="option in actionTypeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </div>

        <!-- Single Template (execute_template) -->
        <div v-if="action.type === 'execute_template'" class="space-y-2">
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            {{ t('AGENT_BOTS.NODE_CONFIG.SELECT_TEMPLATE') }}
          </label>
          <select
            :value="action.template_id"
            class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-white focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent text-n-slate-12"
            @change="
              e =>
                onTemplateSelect(
                  actionIndex,
                  e.target.value ? Number(e.target.value) : null
                )
            "
          >
            <option :value="null">
              {{ t('AGENT_BOTS.NODE_CONFIG.CHOOSE_TEMPLATE') }}
            </option>
            <option
              v-for="option in templateOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>

          <!-- Template Details -->
          <div
            v-if="action.template_id && getTemplateDetails(action.template_id)"
            class="mt-2 p-3 bg-n-slate-3 rounded-lg border border-n-weak"
          >
            <div class="flex items-start justify-between mb-2">
              <div class="flex-1">
                <div class="font-medium text-n-slate-12 text-sm">
                  {{ getTemplateDetails(action.template_id).name }}
                </div>
                <div class="text-n-slate-10 text-xs mt-1">
                  {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_TYPE') }}:
                  {{ getTemplateDetails(action.template_id).template_type }}
                </div>
              </div>
              <div class="flex items-center gap-1">
                <Button
                  v-tooltip="t('AGENT_BOTS.NODE_CONFIG.EDIT_TEMPLATE')"
                  variant="slate"
                  icon="i-lucide-edit"
                  size="xs"
                  @click="editTemplate(action.template_id)"
                />
                <Button
                  v-tooltip="
                    expandedTemplates.includes(action.template_id)
                      ? t('AGENT_BOTS.NODE_CONFIG.HIDE_DETAILS')
                      : t('AGENT_BOTS.NODE_CONFIG.SHOW_DETAILS')
                  "
                  variant="slate"
                  icon="i-lucide-info"
                  size="xs"
                  @click="toggleTemplateDetails(action.template_id)"
                />
              </div>
            </div>

            <!-- Expanded Template Parameters -->
            <div
              v-if="expandedTemplates.includes(action.template_id)"
              class="mt-3 pt-3 border-t border-n-weak"
            >
              <div class="text-xs font-medium text-n-slate-11 mb-2">
                {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_PARAMETERS') }}
              </div>
              <div class="space-y-2">
                <div
                  v-for="(value, key) in getTemplateDetails(action.template_id)
                    .parameters"
                  :key="key"
                  class="flex flex-col gap-1"
                >
                  <span class="text-xs font-medium text-n-slate-12"
                    >{{ key }}:</span
                  >
                  <div
                    class="text-xs text-n-slate-10 bg-n-slate-2 p-2 rounded font-mono break-words"
                  >
                    {{
                      typeof value === 'object'
                        ? JSON.stringify(value, null, 2)
                        : value
                    }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Multiple Templates (execute_templates) -->
        <div v-else-if="action.type === 'execute_templates'" class="space-y-2">
          <div class="flex items-center justify-between">
            <label class="block text-xs font-medium text-n-slate-11">
              {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATES_SEQUENCE') }}
            </label>
            <Button
              variant="slate"
              icon="i-lucide-plus"
              size="xs"
              @click="addTemplateToArray(actionIndex)"
            >
              {{ t('AGENT_BOTS.NODE_CONFIG.ADD_TEMPLATE') }}
            </Button>
          </div>

          <!-- Template IDs Array -->
          <div
            v-for="(templateId, templateIndex) in action.template_ids || []"
            :key="`template-${actionIndex}-${templateIndex}`"
            class="flex items-start gap-2"
          >
            <div class="flex-1">
              <select
                :value="templateId"
                class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-white focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent text-n-slate-12"
                @change="
                  e =>
                    updateTemplateInArray(
                      actionIndex,
                      templateIndex,
                      e.target.value ? Number(e.target.value) : null
                    )
                "
              >
                <option :value="null">
                  {{
                    t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_NUMBER', {
                      number: templateIndex + 1,
                    })
                  }}
                </option>
                <option
                  v-for="option in templateOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>

              <!-- Template Details -->
              <div
                v-if="templateId && getTemplateDetails(templateId)"
                class="mt-2 p-3 bg-n-slate-3 rounded-lg border border-n-weak"
              >
                <div class="flex items-start justify-between mb-2">
                  <div class="flex-1">
                    <div class="font-medium text-n-slate-12 text-sm">
                      {{ getTemplateDetails(templateId).name }}
                    </div>
                    <div class="text-n-slate-10 text-xs mt-1">
                      {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_TYPE') }}:
                      {{ getTemplateDetails(templateId).template_type }}
                    </div>
                  </div>
                  <div class="flex items-center gap-1">
                    <Button
                      v-tooltip="t('AGENT_BOTS.NODE_CONFIG.EDIT_TEMPLATE')"
                      variant="slate"
                      icon="i-lucide-edit"
                      size="xs"
                      @click="editTemplate(templateId)"
                    />
                    <Button
                      v-tooltip="
                        expandedTemplates.includes(templateId)
                          ? t('AGENT_BOTS.NODE_CONFIG.HIDE_DETAILS')
                          : t('AGENT_BOTS.NODE_CONFIG.SHOW_DETAILS')
                      "
                      variant="slate"
                      icon="i-lucide-info"
                      size="xs"
                      @click="toggleTemplateDetails(templateId)"
                    />
                  </div>
                </div>

                <!-- Expanded Template Parameters -->
                <div
                  v-if="expandedTemplates.includes(templateId)"
                  class="mt-3 pt-3 border-t border-n-weak"
                >
                  <div class="text-xs font-medium text-n-slate-11 mb-2">
                    {{ t('AGENT_BOTS.NODE_CONFIG.TEMPLATE_PARAMETERS') }}
                  </div>
                  <div class="space-y-2">
                    <div
                      v-for="(value, key) in getTemplateDetails(templateId)
                        .parameters"
                      :key="key"
                      class="flex flex-col gap-1"
                    >
                      <span class="text-xs font-medium text-n-slate-12"
                        >{{ key }}:</span
                      >
                      <div
                        class="text-xs text-n-slate-10 bg-n-slate-2 p-2 rounded font-mono break-words"
                      >
                        {{
                          typeof value === 'object'
                            ? JSON.stringify(value, null, 2)
                            : value
                        }}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <Button
              variant="slate"
              icon="i-lucide-x"
              size="xs"
              class="mt-1"
              @click="removeTemplateFromArray(actionIndex, templateIndex)"
            />
          </div>

          <p
            v-if="!action.template_ids || action.template_ids.length === 0"
            class="text-xs text-n-slate-10 italic"
          >
            {{ t('AGENT_BOTS.NODE_CONFIG.NO_TEMPLATES_ADDED') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else
      class="p-8 text-center bg-n-slate-2 border border-n-weak rounded-lg border-dashed"
    >
      <i class="i-lucide-zap text-4xl text-n-slate-8 mb-2" />
      <p class="text-sm text-n-slate-11 mb-4">
        {{ t('AGENT_BOTS.NODE_CONFIG.NO_ACTIONS') }}
      </p>
      <Button
        variant="primary"
        icon="i-lucide-plus"
        size="sm"
        @click="addAction"
      >
        {{ t('AGENT_BOTS.NODE_CONFIG.ADD_FIRST_ACTION') }}
      </Button>
    </div>

    <!-- Action Template Editor Dialog -->
    <ActionTemplateEditor
      ref="templateEditorRef"
      :account-id="accountId"
      :template="editingTemplate"
      @save="handleTemplateSave"
      @close="editingTemplate = null"
    />
  </div>
</template>

<style scoped>
.state-actions-editor {
  /* Component styles using Tailwind */
}
</style>
