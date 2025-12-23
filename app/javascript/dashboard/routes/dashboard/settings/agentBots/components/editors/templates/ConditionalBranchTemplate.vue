<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const expressionError = ref('');

// Condition type
const conditionType = computed({
  get: () => props.modelValue.condition_type || '',
  set: value => {
    // Reset condition_value when type changes
    emit('update:modelValue', {
      ...props.modelValue,
      condition_type: value,
      condition_value: {},
    });
  },
});

// Attribute-based conditions
const attributeName = computed({
  get: () => props.modelValue.condition_value?.attribute || '',
  set: value => {
    const conditionValue = {
      ...props.modelValue.condition_value,
      attribute: value,
    };
    emit('update:modelValue', {
      ...props.modelValue,
      condition_value: conditionValue,
    });
  },
});

const attributeValue = computed({
  get: () => props.modelValue.condition_value?.value || '',
  set: value => {
    const conditionValue = {
      ...props.modelValue.condition_value,
      value,
    };
    emit('update:modelValue', {
      ...props.modelValue,
      condition_value: conditionValue,
    });
  },
});

// Message contains
const messageText = computed({
  get: () => props.modelValue.condition_value?.text || '',
  set: value => {
    emit('update:modelValue', {
      ...props.modelValue,
      condition_value: { text: value },
    });
  },
});

// Custom expression
const customExpression = computed({
  get: () => props.modelValue.condition_value?.expression || '',
  set: value => {
    expressionError.value = '';
    emit('update:modelValue', {
      ...props.modelValue,
      condition_value: { expression: value },
    });
  },
});

// Actions
const trueAction = computed({
  get: () => props.modelValue.true_action || null,
  set: value =>
    emit('update:modelValue', { ...props.modelValue, true_action: value }),
});

const falseAction = computed({
  get: () => props.modelValue.false_action || null,
  set: value =>
    emit('update:modelValue', { ...props.modelValue, false_action: value }),
});

// Preview text
const conditionPreview = computed(() => {
  const type = conditionType.value;
  const val = props.modelValue.condition_value;

  switch (type) {
    case 'attribute_equals':
      return t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PREVIEW.ATTRIBUTE_EQUALS',
        { attribute: val?.attribute || '?', value: val?.value || '?' }
      );
    case 'attribute_contains':
      return t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PREVIEW.ATTRIBUTE_CONTAINS',
        { attribute: val?.attribute || '?', value: val?.value || '?' }
      );
    case 'message_contains':
      return t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PREVIEW.MESSAGE_CONTAINS',
        { text: val?.text || '?' }
      );
    case 'custom_expression':
      return t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PREVIEW.CUSTOM_EXPRESSION',
        { expression: val?.expression || '?' }
      );
    default:
      return t(
        'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PREVIEW.SELECT_TYPE'
      );
  }
});
</script>

<template>
  <div class="space-y-4">
    <!-- Condition Type Selector -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.CONDITION_TYPE'
          )
        }}
        *
      </label>
      <select
        v-model="conditionType"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
      >
        <option value="">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.SELECT_TYPE'
            )
          }}
        </option>
        <option value="attribute_equals">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TYPES.ATTRIBUTE_EQUALS'
            )
          }}
        </option>
        <option value="attribute_contains">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TYPES.ATTRIBUTE_CONTAINS'
            )
          }}
        </option>
        <option value="message_contains">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TYPES.MESSAGE_CONTAINS'
            )
          }}
        </option>
        <option value="custom_expression">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TYPES.CUSTOM_EXPRESSION'
            )
          }}
        </option>
      </select>
    </div>

    <!-- Condition Value (Dynamic based on type) -->
    <div v-if="conditionType">
      <!-- attribute_equals / attribute_contains -->
      <div
        v-if="
          conditionType === 'attribute_equals' ||
          conditionType === 'attribute_contains'
        "
        class="space-y-3"
      >
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{
              t(
                'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.ATTRIBUTE_NAME'
              )
            }}
            *
          </label>
          <input
            v-model="attributeName"
            class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
            :placeholder="
              t(
                'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.ATTRIBUTE_NAME_PLACEHOLDER'
              )
            "
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{
              t(
                'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.ATTRIBUTE_VALUE'
              )
            }}
            *
          </label>
          <input
            v-model="attributeValue"
            class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
            :placeholder="
              t(
                'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.ATTRIBUTE_VALUE_PLACEHOLDER'
              )
            "
          />
        </div>
      </div>

      <!-- message_contains -->
      <div v-else-if="conditionType === 'message_contains'">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.MESSAGE_TEXT'
            )
          }}
          *
        </label>
        <input
          v-model="messageText"
          class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
          :placeholder="
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.MESSAGE_TEXT_PLACEHOLDER'
            )
          "
        />
        <p class="mt-1 text-xs text-n-slate-11">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.MESSAGE_TEXT_HELP'
            )
          }}
        </p>
      </div>

      <!-- custom_expression -->
      <div v-else-if="conditionType === 'custom_expression'">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.CUSTOM_EXPRESSION'
            )
          }}
          *
        </label>
        <textarea
          v-model="customExpression"
          rows="4"
          class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 font-mono text-sm"
          :class="
            expressionError
              ? 'border-red-500 focus:ring-red-500'
              : 'border-n-weak focus:ring-n-blue-8'
          "
          :placeholder="
            t(
              'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.CUSTOM_EXPRESSION_PLACEHOLDER'
            )
          "
        />
        <div class="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <p class="text-xs text-yellow-800">
            {{
              t(
                'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.CUSTOM_EXPRESSION_WARNING'
              )
            }}
          </p>
        </div>
      </div>
    </div>

    <!-- True Action -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TRUE_ACTION'
          )
        }}
      </label>
      <input
        v-model.number="trueAction"
        type="number"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TRUE_ACTION_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.TRUE_ACTION_HELP'
          )
        }}
      </p>
    </div>

    <!-- False Action -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.FALSE_ACTION'
          )
        }}
      </label>
      <input
        v-model.number="falseAction"
        type="number"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.FALSE_ACTION_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.FALSE_ACTION_HELP'
          )
        }}
      </p>
    </div>

    <!-- Preview -->
    <div
      v-if="conditionType"
      class="p-4 bg-n-slate-2 border border-n-weak rounded-lg"
    >
      <p class="text-xs font-medium text-n-slate-12 mb-1">
        {{
          t(
            'AGENT_BOTS.ACTION_TEMPLATES.TYPES.CONDITIONAL_BRANCH.PARAMETERS.PREVIEW'
          )
        }}
      </p>
      <p class="text-sm text-n-slate-11">
        {{ conditionPreview }}
      </p>
    </div>
  </div>
</template>
