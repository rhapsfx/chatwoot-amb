<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
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

// Local editable state
const editedData = ref({
  keywords: [],
  exact_match: false,
  case_sensitive: false,
  scope: 'global', // global or contextual
});

const newKeyword = ref('');

// Initialize with node data
watch(
  () => props.node,
  newNode => {
    if (newNode?.data) {
      editedData.value = {
        keywords: newNode.data.keywords || [],
        exact_match: newNode.data.exact_match || false,
        case_sensitive: newNode.data.case_sensitive || false,
        scope: newNode.data.scope || 'global', // default to global for backward compatibility
      };
    }
  },
  { immediate: true }
);

const addKeyword = () => {
  if (newKeyword.value.trim()) {
    editedData.value.keywords.push(newKeyword.value.trim());
    newKeyword.value = '';
  }
};

const removeKeyword = index => {
  editedData.value.keywords.splice(index, 1);
};

const handleSave = () => {
  emit('save', editedData.value);
};

const handleCancel = () => {
  emit('cancel');
};
</script>

<template>
  <div class="intent-node-editor">
    <h3 class="text-lg font-semibold text-n-slate-12 mb-4">
      {{ t('AGENT_BOTS.EDITORS.EDIT_INTENT_NODE') }}
    </h3>

    <div class="space-y-4">
      <!-- Keywords -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-1">
          {{ t('AGENT_BOTS.EDITORS.KEYWORDS') }}
        </label>
        <div class="flex gap-2 mb-2">
          <Input
            v-model="newKeyword"
            placeholder="Add keyword..."
            class="flex-1"
            @keyup.enter="addKeyword"
          />
          <Button icon="i-lucide-plus" variant="primary" @click="addKeyword">
            {{ t('AGENT_BOTS.NODE_CONFIG.ADD') }}
          </Button>
        </div>
        <div class="flex flex-wrap gap-2">
          <div
            v-for="(keyword, index) in editedData.keywords"
            :key="index"
            class="inline-flex items-center gap-1 px-2 py-1 bg-n-blue-3 text-n-blue-11 rounded text-sm"
          >
            <span>{{ keyword }}</span>
            <button class="hover:text-n-blue-12" @click="removeKeyword(index)">
              <i class="i-lucide-x w-3 h-3" />
            </button>
          </div>
        </div>
        <p class="text-xs text-n-slate-10 mt-1">
          {{ t('AGENT_BOTS.EDITORS.KEYWORDS_TRIGGER_HELP') }}
        </p>
      </div>

      <!-- Options -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ t('AGENT_BOTS.EDITORS.MATCHING_OPTIONS') }}
        </label>
        <div class="space-y-2">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="editedData.exact_match"
              type="checkbox"
              class="rounded"
            />
            <span class="text-sm text-n-slate-11">{{
              t('AGENT_BOTS.NODE_CONFIG.EXACT_MATCH')
            }}</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="editedData.case_sensitive"
              type="checkbox"
              class="rounded"
            />
            <span class="text-sm text-n-slate-11">{{
              t('AGENT_BOTS.NODE_CONFIG.CASE_SENSITIVE')
            }}</span>
          </label>
        </div>
      </div>

      <!-- Intent Scope -->
      <div>
        <label class="block text-sm font-medium text-n-slate-11 mb-2">
          {{ t('AGENT_BOTS.EDITORS.INTENT_SCOPE') }}
        </label>
        <div class="space-y-2">
          <label class="flex items-start gap-2 cursor-pointer">
            <input
              v-model="editedData.scope"
              type="radio"
              value="global"
              class="mt-0.5"
            />
            <div class="flex-1">
              <div class="flex items-center gap-1">
                <i class="i-lucide-globe text-n-blue-11 w-4 h-4" />
                <span class="text-sm font-medium text-n-slate-12">Global</span>
              </div>
              <p class="text-xs text-n-slate-10 mt-0.5">
                Always checked on every message (for startover, stop, menu, help, reset)
              </p>
            </div>
          </label>
          <label class="flex items-start gap-2 cursor-pointer">
            <input
              v-model="editedData.scope"
              type="radio"
              value="contextual"
              class="mt-0.5"
            />
            <div class="flex-1">
              <div class="flex items-center gap-1">
                <i class="i-lucide-git-branch text-n-purple-11 w-4 h-4" />
                <span class="text-sm font-medium text-n-slate-12">Contextual</span>
              </div>
              <p class="text-xs text-n-slate-10 mt-0.5">
                Only checked when connected to current state (for feature-specific intents)
              </p>
            </div>
          </label>
        </div>
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
.intent-node-editor {
  padding: 0;
}
</style>
