<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const localData = ref({
  condition_type: 'simple',
  condition_expression: '',
  true_label: 'Yes',
  false_label: 'No',
  field_name: '',
  operator: 'equals',
  compare_value: '',
  ...props.modelValue,
});

watch(
  localData,
  newVal => {
    emit('update:modelValue', newVal);
  },
  { deep: true }
);

const conditionTypeOptions = computed(() => [
  {
    value: 'simple',
    label: t('AGENT_BOTS.CONDITION_CONFIG.CONDITION_TYPES.SIMPLE'),
  },
  {
    value: 'expression',
    label: t('AGENT_BOTS.CONDITION_CONFIG.CONDITION_TYPES.EXPRESSION'),
  },
]);

const operatorOptions = computed(() => [
  { value: 'equals', label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.EQUALS') },
  {
    value: 'not_equals',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.NOT_EQUALS'),
  },
  {
    value: 'contains',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.CONTAINS'),
  },
  {
    value: 'not_contains',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.NOT_CONTAINS'),
  },
  {
    value: 'greater_than',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.GREATER_THAN'),
  },
  {
    value: 'less_than',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.LESS_THAN'),
  },
  { value: 'exists', label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.EXISTS') },
  {
    value: 'not_exists',
    label: t('AGENT_BOTS.CONDITION_CONFIG.OPERATORS.NOT_EXISTS'),
  },
]);

const isSimpleCondition = computed(() => {
  return localData.value.condition_type === 'simple';
});

const generateExpression = () => {
  const { field_name, operator, compare_value } = localData.value;

  if (!field_name) {
    localData.value.condition_expression = '';
    return;
  }

  let expression = '';
  switch (operator) {
    case 'equals':
      expression = `${field_name} == "${compare_value}"`;
      break;
    case 'not_equals':
      expression = `${field_name} != "${compare_value}"`;
      break;
    case 'contains':
      expression = `${field_name}.includes("${compare_value}")`;
      break;
    case 'not_contains':
      expression = `!${field_name}.includes("${compare_value}")`;
      break;
    case 'greater_than':
      expression = `${field_name} > ${compare_value}`;
      break;
    case 'less_than':
      expression = `${field_name} < ${compare_value}`;
      break;
    case 'exists':
      expression = `${field_name} !== null && ${field_name} !== undefined`;
      break;
    case 'not_exists':
      expression = `${field_name} === null || ${field_name} === undefined`;
      break;
    default:
      expression = '';
  }

  localData.value.condition_expression = expression;
};

watch(
  () => [
    localData.value.field_name,
    localData.value.operator,
    localData.value.compare_value,
  ],
  () => {
    if (isSimpleCondition.value) {
      generateExpression();
    }
  },
  { deep: true }
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <SelectMenu
      v-model="localData.condition_type"
      :label="t('AGENT_BOTS.CONDITION_CONFIG.CONDITION_TYPE_LABEL')"
      :options="conditionTypeOptions"
    />

    <div v-if="isSimpleCondition" class="simple-condition">
      <h4 class="text-sm font-medium text-n-slate-12 mb-3">
        {{ t('AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.TITLE') }}
      </h4>

      <Input
        v-model="localData.field_name"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.FIELD_NAME')"
        :placeholder="
          t(
            'AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.FIELD_NAME_PLACEHOLDER'
          )
        "
        :message="
          t('AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.FIELD_NAME_MESSAGE')
        "
      />

      <SelectMenu
        v-model="localData.operator"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.OPERATOR')"
        :options="operatorOptions"
      />

      <Input
        v-if="!['exists', 'not_exists'].includes(localData.operator)"
        v-model="localData.compare_value"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.COMPARE_VALUE')"
        :placeholder="
          t(
            'AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.COMPARE_VALUE_PLACEHOLDER'
          )
        "
      />

      <div class="expression-preview">
        <label class="block mb-1 text-xs font-medium text-n-slate-11">
          {{
            t(
              'AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.GENERATED_EXPRESSION'
            )
          }}
        </label>
        <code class="expression-code">
          {{
            localData.condition_expression ||
            t(
              'AGENT_BOTS.CONDITION_CONFIG.SIMPLE_CONDITION.CONFIGURE_FIELDS_MESSAGE'
            )
          }}
        </code>
      </div>
    </div>

    <div v-else>
      <TextArea
        v-model="localData.condition_expression"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.CUSTOM_EXPRESSION.LABEL')"
        :placeholder="
          t('AGENT_BOTS.CONDITION_CONFIG.CUSTOM_EXPRESSION.PLACEHOLDER')
        "
        :max-length="500"
        :message="t('AGENT_BOTS.CONDITION_CONFIG.CUSTOM_EXPRESSION.MESSAGE')"
      />
    </div>

    <div class="border-t border-n-weak pt-4 mt-2">
      <h4 class="text-sm font-medium text-n-slate-12 mb-3">
        {{ t('AGENT_BOTS.CONDITION_CONFIG.OUTPUT_LABELS.TITLE') }}
      </h4>

      <Input
        v-model="localData.true_label"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.OUTPUT_LABELS.TRUE_LABEL')"
        :placeholder="
          t('AGENT_BOTS.CONDITION_CONFIG.OUTPUT_LABELS.TRUE_LABEL_PLACEHOLDER')
        "
      />

      <Input
        v-model="localData.false_label"
        :label="t('AGENT_BOTS.CONDITION_CONFIG.OUTPUT_LABELS.FALSE_LABEL')"
        :placeholder="
          t('AGENT_BOTS.CONDITION_CONFIG.OUTPUT_LABELS.FALSE_LABEL_PLACEHOLDER')
        "
      />
    </div>

    <div class="p-3 bg-n-slate-2 rounded-lg border border-n-weak">
      <h5 class="text-xs font-medium text-n-slate-12 mb-1">
        {{ t('AGENT_BOTS.CONDITION_CONFIG.INFO.TITLE') }}
      </h5>
      <p class="text-xs text-n-slate-10">
        {{ t('AGENT_BOTS.CONDITION_CONFIG.INFO.DESCRIPTION') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.simple-condition {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 12px;
  background: var(--n-slate-2);
  border-radius: 8px;
  border: 1px solid var(--n-weak);
}

.expression-preview {
  margin-top: 8px;
}

.expression-code {
  display: block;
  padding: 8px 12px;
  background: var(--n-slate-1);
  border: 1px solid var(--n-weak);
  border-radius: 6px;
  font-size: 12px;
  font-family: 'Monaco', 'Menlo', 'Courier New', monospace;
  color: var(--n-slate-12);
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
