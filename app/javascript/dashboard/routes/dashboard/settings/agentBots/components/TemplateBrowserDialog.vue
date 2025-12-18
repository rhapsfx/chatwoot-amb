<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['insertTemplate']);

const { t } = useI18n();

const dialogRef = ref(null);
const selectedTemplate = ref(null);
const selectedCategory = ref('all');

// Template definitions with pre-configured nodes and connections
const templates = ref([
  {
    id: 'customer-support',
    name: 'Customer Support Flow',
    description:
      'Handle common support inquiries with intent detection and routing',
    category: 'support',
    icon: 'i-lucide-headphones',
    preview: {
      nodes: 5,
      connections: 6,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'Welcome',
            stateId: 'welcome',
            description: 'Initial greeting',
          },
        },
        {
          id: 'intent-1',
          type: 'intent',
          position: { x: 300, y: 100 },
          data: {
            label: 'Detect Intent',
            keywords: ['help', 'support', 'issue', 'problem'],
          },
        },
        {
          id: 'condition-1',
          type: 'condition',
          position: { x: 500, y: 100 },
          data: {
            label: 'Route by Priority',
            expression: 'intent.confidence > 0.8',
          },
        },
        {
          id: 'action-1',
          type: 'action',
          position: { x: 700, y: 50 },
          data: {
            label: 'High Priority',
            actionType: 'assign_agent',
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 700, y: 150 },
          data: {
            label: 'Send FAQ',
            templateName: 'faq_response',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'intent-1', type: 'default' },
        {
          id: 'e2',
          source: 'intent-1',
          target: 'condition-1',
          type: 'default',
        },
        {
          id: 'e3',
          source: 'condition-1',
          target: 'action-1',
          type: 'true',
          label: 'High Priority',
        },
        {
          id: 'e4',
          source: 'condition-1',
          target: 'template-1',
          type: 'false',
          label: 'Standard',
        },
      ],
    },
  },
  {
    id: 'order-status',
    name: 'Order Status Inquiry',
    description:
      'Let customers check their order status with automated responses',
    category: 'commerce',
    icon: 'i-lucide-package',
    preview: {
      nodes: 4,
      connections: 4,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'Order Inquiry',
            stateId: 'order_start',
            description: 'Customer asks about order',
          },
        },
        {
          id: 'action-1',
          type: 'action',
          position: { x: 300, y: 100 },
          data: {
            label: 'Fetch Order',
            actionType: 'api_call',
          },
        },
        {
          id: 'condition-1',
          type: 'condition',
          position: { x: 500, y: 100 },
          data: {
            label: 'Order Found?',
            expression: 'order.exists',
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 700, y: 100 },
          data: {
            label: 'Order Status',
            templateName: 'order_status',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'action-1', type: 'default' },
        {
          id: 'e2',
          source: 'action-1',
          target: 'condition-1',
          type: 'default',
        },
        {
          id: 'e3',
          source: 'condition-1',
          target: 'template-1',
          type: 'true',
          label: 'Found',
        },
      ],
    },
  },
  {
    id: 'faq-handler',
    name: 'FAQ Handler',
    description: 'Answer frequently asked questions automatically',
    category: 'support',
    icon: 'i-lucide-message-circle-question',
    preview: {
      nodes: 6,
      connections: 7,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'FAQ Start',
            stateId: 'faq_start',
            description: 'User asks question',
          },
        },
        {
          id: 'intent-1',
          type: 'intent',
          position: { x: 300, y: 100 },
          data: {
            label: 'Detect Question Type',
            keywords: ['hours', 'location', 'pricing', 'shipping'],
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 500, y: 50 },
          data: {
            label: 'Hours Info',
            templateName: 'business_hours',
          },
        },
        {
          id: 'template-2',
          type: 'template',
          position: { x: 500, y: 120 },
          data: {
            label: 'Location Info',
            templateName: 'location_info',
          },
        },
        {
          id: 'template-3',
          type: 'template',
          position: { x: 500, y: 190 },
          data: {
            label: 'Pricing Info',
            templateName: 'pricing_info',
          },
        },
        {
          id: 'action-1',
          type: 'action',
          position: { x: 700, y: 100 },
          data: {
            label: 'Escalate to Agent',
            actionType: 'assign_agent',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'intent-1', type: 'default' },
        {
          id: 'e2',
          source: 'intent-1',
          target: 'template-1',
          type: 'intent',
          label: 'Hours',
        },
        {
          id: 'e3',
          source: 'intent-1',
          target: 'template-2',
          type: 'intent',
          label: 'Location',
        },
        {
          id: 'e4',
          source: 'intent-1',
          target: 'template-3',
          type: 'intent',
          label: 'Pricing',
        },
        { id: 'e5', source: 'template-1', target: 'action-1', type: 'default' },
        { id: 'e6', source: 'template-2', target: 'action-1', type: 'default' },
        { id: 'e7', source: 'template-3', target: 'action-1', type: 'default' },
      ],
    },
  },
  {
    id: 'appointment-booking',
    name: 'Appointment Booking',
    description: 'Guide customers through booking an appointment',
    category: 'scheduling',
    icon: 'i-lucide-calendar-check',
    preview: {
      nodes: 5,
      connections: 5,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'Booking Start',
            stateId: 'booking_start',
            description: 'Customer wants to book',
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 300, y: 100 },
          data: {
            label: 'Show Time Picker',
            templateName: 'time_picker',
          },
        },
        {
          id: 'condition-1',
          type: 'condition',
          position: { x: 500, y: 100 },
          data: {
            label: 'Time Available?',
            expression: 'slot.available',
          },
        },
        {
          id: 'action-1',
          type: 'action',
          position: { x: 700, y: 50 },
          data: {
            label: 'Confirm Booking',
            actionType: 'create_appointment',
          },
        },
        {
          id: 'template-2',
          type: 'template',
          position: { x: 700, y: 150 },
          data: {
            label: 'Suggest Alternative',
            templateName: 'alternative_times',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'template-1', type: 'default' },
        {
          id: 'e2',
          source: 'template-1',
          target: 'condition-1',
          type: 'default',
        },
        {
          id: 'e3',
          source: 'condition-1',
          target: 'action-1',
          type: 'true',
          label: 'Available',
        },
        {
          id: 'e4',
          source: 'condition-1',
          target: 'template-2',
          type: 'false',
          label: 'Unavailable',
        },
        {
          id: 'e5',
          source: 'template-2',
          target: 'template-1',
          type: 'default',
        },
      ],
    },
  },
  {
    id: 'feedback-collection',
    name: 'Feedback Collection',
    description: 'Collect customer feedback and ratings',
    category: 'engagement',
    icon: 'i-lucide-star',
    preview: {
      nodes: 4,
      connections: 4,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'Feedback Start',
            stateId: 'feedback_start',
            description: 'Ask for feedback',
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 300, y: 100 },
          data: {
            label: 'Rating Picker',
            templateName: 'rating_picker',
          },
        },
        {
          id: 'condition-1',
          type: 'condition',
          position: { x: 500, y: 100 },
          data: {
            label: 'Positive Rating?',
            expression: 'rating >= 4',
          },
        },
        {
          id: 'template-2',
          type: 'template',
          position: { x: 700, y: 100 },
          data: {
            label: 'Thank You',
            templateName: 'thank_you',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'template-1', type: 'default' },
        {
          id: 'e2',
          source: 'template-1',
          target: 'condition-1',
          type: 'default',
        },
        {
          id: 'e3',
          source: 'condition-1',
          target: 'template-2',
          type: 'true',
          label: 'Positive',
        },
        {
          id: 'e4',
          source: 'condition-1',
          target: 'template-2',
          type: 'false',
          label: 'Negative',
        },
      ],
    },
  },
  {
    id: 'lead-qualification',
    name: 'Lead Qualification',
    description: 'Qualify leads and route to appropriate sales team',
    category: 'sales',
    icon: 'i-lucide-user-check',
    preview: {
      nodes: 6,
      connections: 6,
    },
    flowData: {
      nodes: [
        {
          id: 'start',
          type: 'state',
          position: { x: 100, y: 100 },
          data: {
            label: 'Lead Start',
            stateId: 'lead_start',
            description: 'New lead inquiry',
          },
        },
        {
          id: 'template-1',
          type: 'template',
          position: { x: 300, y: 100 },
          data: {
            label: 'Collect Info',
            templateName: 'lead_form',
          },
        },
        {
          id: 'condition-1',
          type: 'condition',
          position: { x: 500, y: 100 },
          data: {
            label: 'Qualified Lead?',
            expression: 'lead.score > 50',
          },
        },
        {
          id: 'action-1',
          type: 'action',
          position: { x: 700, y: 50 },
          data: {
            label: 'Route to Sales',
            actionType: 'assign_to_sales',
          },
        },
        {
          id: 'action-2',
          type: 'action',
          position: { x: 700, y: 150 },
          data: {
            label: 'Add to Nurture',
            actionType: 'add_to_campaign',
          },
        },
        {
          id: 'template-2',
          type: 'template',
          position: { x: 900, y: 100 },
          data: {
            label: 'Confirmation',
            templateName: 'lead_confirmation',
          },
        },
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'template-1', type: 'default' },
        {
          id: 'e2',
          source: 'template-1',
          target: 'condition-1',
          type: 'default',
        },
        {
          id: 'e3',
          source: 'condition-1',
          target: 'action-1',
          type: 'true',
          label: 'High Score',
        },
        {
          id: 'e4',
          source: 'condition-1',
          target: 'action-2',
          type: 'false',
          label: 'Low Score',
        },
        { id: 'e5', source: 'action-1', target: 'template-2', type: 'default' },
        { id: 'e6', source: 'action-2', target: 'template-2', type: 'default' },
      ],
    },
  },
]);

const categories = computed(() => [
  {
    value: 'all',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.ALL'),
    icon: 'i-lucide-layout-grid',
  },
  {
    value: 'support',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.SUPPORT'),
    icon: 'i-lucide-headphones',
  },
  {
    value: 'commerce',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.COMMERCE'),
    icon: 'i-lucide-shopping-cart',
  },
  {
    value: 'scheduling',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.SCHEDULING'),
    icon: 'i-lucide-calendar',
  },
  {
    value: 'engagement',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.ENGAGEMENT'),
    icon: 'i-lucide-users',
  },
  {
    value: 'sales',
    label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.SALES'),
    icon: 'i-lucide-trending-up',
  },
]);

const filteredTemplates = computed(() => {
  if (selectedCategory.value === 'all') {
    return templates.value;
  }
  return templates.value.filter(
    template => template.category === selectedCategory.value
  );
});

const selectTemplate = template => {
  selectedTemplate.value = template;
};

const close = () => {
  dialogRef.value?.close();
  selectedTemplate.value = null;
};

const insertTemplate = () => {
  if (!selectedTemplate.value) return;

  emit('insertTemplate', selectedTemplate.value.flowData);
  close();
};

defineExpose({
  open: () => dialogRef.value?.open(),
  close,
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('AGENT_BOTS.TEMPLATES.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="6xl"
    overflow-y-auto
  >
    <div class="flex flex-col gap-4">
      <!-- Description -->
      <p class="text-sm text-n-slate-11">
        {{ t('AGENT_BOTS.TEMPLATES.DESCRIPTION') }}
      </p>

      <!-- Category Filter -->
      <div class="flex gap-2 overflow-x-auto pb-2">
        <button
          v-for="category in categories"
          :key="category.value"
          class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all whitespace-nowrap"
          :class="[
            selectedCategory === category.value
              ? 'bg-n-blue-8 text-white'
              : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3',
          ]"
          @click="selectedCategory = category.value"
        >
          <i class="w-4 h-4" :class="[category.icon]" />
          <span>{{ category.label }}</span>
        </button>
      </div>

      <!-- Templates Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <button
          v-for="template in filteredTemplates"
          :key="template.id"
          class="flex flex-col gap-3 p-4 rounded-lg border-2 text-left transition-all group"
          :class="[
            selectedTemplate?.id === template.id
              ? 'border-n-blue-8 bg-n-blue-1'
              : 'border-n-weak hover:border-n-strong bg-n-white',
          ]"
          @click="selectTemplate(template)"
        >
          <!-- Header -->
          <div class="flex items-start gap-3">
            <div
              class="flex items-center justify-center w-12 h-12 rounded-lg transition-colors"
              :class="[
                selectedTemplate?.id === template.id
                  ? 'bg-n-blue-8 text-white'
                  : 'bg-n-slate-2 text-n-slate-11 group-hover:bg-n-slate-3',
              ]"
            >
              <i class="w-6 h-6" :class="[template.icon]" />
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-n-slate-12 mb-1">
                {{ template.name }}
              </h3>
              <p class="text-sm text-n-slate-11">
                {{ template.description }}
              </p>
            </div>
          </div>

          <!-- Preview Stats -->
          <div class="flex items-center gap-4 text-xs text-n-slate-11">
            <div class="flex items-center gap-1">
              <i class="i-lucide-circle-dot w-3 h-3" />
              <span>
                {{ template.preview.nodes }}
                {{ t('AGENT_BOTS.TEMPLATES.NODES') }}
              </span>
            </div>
            <div class="flex items-center gap-1">
              <i class="i-lucide-git-branch w-3 h-3" />
              <span>
                {{ template.preview.connections }}
                {{ t('AGENT_BOTS.TEMPLATES.CONNECTIONS') }}
              </span>
            </div>
          </div>

          <!-- Selected Indicator -->
          <div
            v-if="selectedTemplate?.id === template.id"
            class="flex items-center gap-2 text-sm text-n-blue-11 font-medium"
          >
            <i class="i-lucide-check-circle w-4 h-4" />
            <span>{{ t('AGENT_BOTS.TEMPLATES.SELECTED') }}</span>
          </div>
        </button>
      </div>

      <!-- Empty State -->
      <div
        v-if="filteredTemplates.length === 0"
        class="flex flex-col items-center justify-center py-8 text-center"
      >
        <i class="i-lucide-folder-open w-12 h-12 mb-3 text-n-slate-8" />
        <p class="text-sm text-n-slate-11">
          {{ t('AGENT_BOTS.TEMPLATES.NO_TEMPLATES') }}
        </p>
      </div>

      <!-- Footer Actions -->
      <div
        class="flex justify-between items-center pt-4 border-t border-n-weak"
      >
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <i class="i-lucide-info w-4 h-4" />
          <span>{{ t('AGENT_BOTS.TEMPLATES.FOOTER_TIP') }}</span>
        </div>
        <div class="flex gap-2">
          <Button
            faded
            slate
            :label="t('AGENT_BOTS.FORM.CANCEL')"
            @click="close"
          />
          <Button
            :label="t('AGENT_BOTS.TEMPLATES.INSERT')"
            :disabled="!selectedTemplate"
            @click="insertTemplate"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
