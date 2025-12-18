<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localData = ref({
  keywords: [],
  exact_match: false,
  case_sensitive: false,
  ...props.modelValue,
});

const newKeyword = ref('');

watch(
  localData,
  newVal => {
    emit('update:modelValue', newVal);
  },
  { deep: true }
);

const addKeyword = () => {
  if (newKeyword.value.trim()) {
    localData.value.keywords.push(newKeyword.value.trim());
    newKeyword.value = '';
  }
};

const removeKeyword = index => {
  localData.value.keywords.splice(index, 1);
};

const handleKeywordKeypress = event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    addKeyword();
  }
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div>
      <label class="block mb-2 text-sm font-medium text-n-slate-12">
        {{ t('AGENT_BOTS.NODE_CONFIG.KEYWORDS_PHRASES') }}
      </label>
      <div class="flex gap-2 mb-3">
        <Input
          v-model="newKeyword"
          :placeholder="t('AGENT_BOTS.NODE_CONFIG.KEYWORD_PLACEHOLDER')"
          class="flex-1"
          @keypress="handleKeywordKeypress"
        />
        <Button icon="i-lucide-plus" size="sm" @click="addKeyword">
          {{ t('AGENT_BOTS.NODE_CONFIG.ADD') }}
        </Button>
      </div>

      <div v-if="localData.keywords.length > 0" class="flex flex-wrap gap-2">
        <div
          v-for="(keyword, index) in localData.keywords"
          :key="index"
          class="keyword-chip"
        >
          <span class="keyword-text">{{ keyword }}</span>
          <button
            type="button"
            class="keyword-remove"
            @click="removeKeyword(index)"
          >
            <i class="i-lucide-x w-3 h-3" />
          </button>
        </div>
      </div>

      <p v-else class="text-xs text-n-slate-10 mt-2">
        {{ t('AGENT_BOTS.NODE_CONFIG.NO_KEYWORDS') }}
      </p>
    </div>

    <div class="flex flex-col gap-3 pt-2 border-t border-n-weak">
      <Checkbox
        v-model="localData.exact_match"
        :label="t('AGENT_BOTS.NODE_CONFIG.EXACT_MATCH')"
        :help-text="t('AGENT_BOTS.NODE_CONFIG.EXACT_MATCH_HELP')"
      />

      <Checkbox
        v-model="localData.case_sensitive"
        :label="t('AGENT_BOTS.NODE_CONFIG.CASE_SENSITIVE')"
        :help-text="t('AGENT_BOTS.NODE_CONFIG.CASE_SENSITIVE_HELP')"
      />
    </div>

    <div class="p-3 bg-n-slate-2 rounded-lg border border-n-weak">
      <h5 class="text-xs font-medium text-n-slate-12 mb-1">
        {{ t('AGENT_BOTS.NODE_CONFIG.EXAMPLE_USAGE') }}
      </h5>
      <p class="text-xs text-n-slate-10">
        {{ t('AGENT_BOTS.NODE_CONFIG.INTENT_EXAMPLE_DESCRIPTION') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.keyword-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px 4px 12px;
  background: var(--n-slate-3);
  border: 1px solid var(--n-weak);
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  color: var(--n-slate-12);
}

.keyword-text {
  line-height: 1.4;
}

.keyword-remove {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--n-slate-10);
  cursor: pointer;
  transition: all 0.2s;
}

.keyword-remove:hover {
  background: var(--n-slate-5);
  color: var(--n-slate-12);
}
</style>
