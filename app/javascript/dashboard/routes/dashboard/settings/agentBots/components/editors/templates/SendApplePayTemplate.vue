<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const merchantId = computed({
  get: () => props.modelValue.merchant_id || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, merchant_id: value }),
});

const itemName = computed({
  get: () => props.modelValue.item_name || '',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, item_name: value }),
});

const amount = computed({
  get: () => props.modelValue.amount ?? null,
  set: value =>
    emit('update:modelValue', { ...props.modelValue, amount: value }),
});

const currency = computed({
  get: () => props.modelValue.currency || 'USD',
  set: value =>
    emit('update:modelValue', { ...props.modelValue, currency: value }),
});
</script>

<template>
  <div class="space-y-4">
    <!-- Merchant ID -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.MERCHANT_ID'
          )
        }}
        *
      </label>
      <input
        v-model="merchantId"
        type="text"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.MERCHANT_ID_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.MERCHANT_ID_HELP'
          )
        }}
      </p>
    </div>

    <!-- Item Name -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.ITEM_NAME'
          )
        }}
        *
      </label>
      <input
        v-model="itemName"
        type="text"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.ITEM_NAME_PLACEHOLDER'
          )
        "
      />
    </div>

    <!-- Amount -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.AMOUNT'
          )
        }}
        *
      </label>
      <input
        v-model.number="amount"
        type="number"
        min="0"
        step="0.01"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.AMOUNT_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.AMOUNT_HELP'
          )
        }}
      </p>
    </div>

    <!-- Currency -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.CURRENCY'
          )
        }}
      </label>
      <input
        v-model="currency"
        type="text"
        maxlength="3"
        class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8 uppercase"
        :placeholder="
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.CURRENCY_PLACEHOLDER'
          )
        "
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_APPLE_PAY.PARAMETERS.CURRENCY_HELP'
          )
        }}
      </p>
    </div>
  </div>
</template>
