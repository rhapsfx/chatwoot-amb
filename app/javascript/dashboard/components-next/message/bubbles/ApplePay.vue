<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';

const { contentAttributes, content } = useMessageContext();
const { t } = useI18n();

const merchantName = computed(
  () => contentAttributes.value?.merchant_name || 'Apple Pay'
);
const total = computed(() => contentAttributes.value?.total || {});
const lineItems = computed(() => contentAttributes.value?.line_items || []);
const currencyCode = computed(
  () => contentAttributes.value?.currency_code || 'USD'
);

function formatCurrency(amount, currency) {
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount);
}
</script>

<template>
  <BaseBubble>
    <div class="flex flex-col gap-2 p-3 min-w-[200px]">
      <div class="flex items-center gap-2">
        <span class="i-ph-apple-logo text-xl text-n-slate-12" />
        <span class="text-sm font-semibold text-n-slate-12">
          {{ merchantName }}
        </span>
      </div>
      <p v-if="content" class="text-sm text-n-slate-11">{{ content }}</p>
      <div
        v-if="lineItems.length"
        class="flex flex-col gap-1 text-xs text-n-slate-11"
      >
        <div
          v-for="item in lineItems"
          :key="item.label"
          class="flex justify-between"
        >
          <span>{{ item.label }}</span>
          <span>{{ formatCurrency(item.amount, currencyCode) }}</span>
        </div>
      </div>
      <div
        v-if="total.amount"
        class="flex justify-between text-sm font-medium text-n-slate-12 border-t border-n-weak pt-1"
      >
        <span>{{ total.label || 'Total' }}</span>
        <span>{{ formatCurrency(total.amount, currencyCode) }}</span>
      </div>
      <div
        class="flex items-center justify-center gap-1 bg-n-slate-12 text-n-slate-1 rounded-lg py-1.5 px-3 text-xs font-medium mt-1"
      >
        <span class="i-ph-apple-logo" />
        <span>{{ t('APPLE_MESSAGES.PAYMENT.PAY') }}</span>
      </div>
    </div>
  </BaseBubble>
</template>
