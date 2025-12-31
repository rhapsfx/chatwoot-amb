<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import agentBotsAPI from 'dashboard/api/agentBots';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['insertTemplate']);

const { t } = useI18n();
const getters = useStoreGetters();

const dialogRef = ref(null);
const selectedTemplate = ref(null);
const selectedCategory = ref('all');
const templates = ref([]);
const isLoading = ref(false);
const loadError = ref(null);

const currentAccountId = computed(() => getters.getCurrentAccountId.value);

// Category mapping for icons
const categoryIcons = {
  navigation: 'i-lucide-compass',
  commerce: 'i-lucide-shopping-cart',
  scheduling: 'i-lucide-calendar-check',
  data_collection: 'i-lucide-clipboard-list',
  support: 'i-lucide-headphones',
  engagement: 'i-lucide-users',
  sales: 'i-lucide-trending-up',
};

// Fallback to hardcoded templates if API fails
const loadFallbackTemplates = () => {
  templates.value = [
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
        nodes: [],
        edges: [],
      },
    },
  ];
};

// Load templates from API
const loadTemplates = async () => {
  if (!currentAccountId.value) return;

  isLoading.value = true;
  loadError.value = null;

  try {
    // Use a temporary agent bot ID (1) - the templates endpoint doesn't actually use this
    // since it queries all template bots for the account
    const response = await agentBotsAPI.getFlowTemplates(
      currentAccountId.value,
      1
    );

    // Map API response to component format
    templates.value = response.data.templates.map(apiTemplate => ({
      id: apiTemplate.id,
      name: apiTemplate.name,
      description:
        apiTemplate.description || apiTemplate.metadata?.description || '',
      category: apiTemplate.metadata?.category || 'support',
      icon: categoryIcons[apiTemplate.metadata?.category] || 'i-lucide-file',
      preview: {
        nodes: apiTemplate.node_count || 0,
        connections: apiTemplate.edge_count || 0,
      },
      flowData: apiTemplate.flow_data || { nodes: [], edges: [] },
    }));
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load flow templates:', error);
    loadError.value = error.message || 'Failed to load templates';
    // Keep hardcoded fallback templates for backward compatibility
    loadFallbackTemplates();
  } finally {
    isLoading.value = false;
  }
};

loadTemplates();

// Computed categories for filter
const categories = computed(() => {
  const cats = new Set(templates.value.map(template => template.category));
  return [
    { value: 'all', label: t('AGENT_BOTS.TEMPLATES.CATEGORIES.ALL') },
    ...Array.from(cats).map(cat => ({
      value: cat,
      label: t(`AGENT_BOTS.TEMPLATES.CATEGORIES.${cat.toUpperCase()}`),
    })),
  ];
});

// Filter templates by category
const filteredTemplates = computed(() => {
  if (selectedCategory.value === 'all') {
    return templates.value;
  }
  return templates.value.filter(
    template => template.category === selectedCategory.value
  );
});

// Dialog methods
const open = () => {
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
  selectedTemplate.value = null;
};

const selectTemplate = template => {
  selectedTemplate.value = template;
};

const insertTemplate = () => {
  if (selectedTemplate.value) {
    emit('insertTemplate', selectedTemplate.value.flowData);
    close();
  }
};

defineExpose({
  open,
  close,
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('AGENT_BOTS.TEMPLATES.BROWSER.TITLE')"
    size="xl"
  >
    <div class="flex flex-col gap-4 h-[600px]">
      <!-- Category Filter -->
      <div class="flex gap-2">
        <button
          v-for="cat in categories"
          :key="cat.value"
          class="px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          :class="[
            selectedCategory === cat.value
              ? 'bg-n-blue-9 text-white'
              : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4',
          ]"
          @click="selectedCategory = cat.value"
        >
          {{ cat.label }}
        </button>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <div class="flex flex-col items-center gap-3">
          <div
            class="w-8 h-8 border-4 border-n-blue-9 border-t-transparent rounded-full animate-spin"
          />
          <p class="text-sm text-n-slate-11">
            {{ t('AGENT_BOTS.TEMPLATES.BROWSER.LOADING') }}
          </p>
        </div>
      </div>

      <!-- Error State -->
      <div v-else-if="loadError" class="flex items-center justify-center py-12">
        <div class="flex flex-col items-center gap-3 max-w-md text-center px-4">
          <i class="i-lucide-alert-circle w-12 h-12 text-n-red-11" />
          <p class="text-sm text-n-slate-12 font-medium">
            {{ t('AGENT_BOTS.TEMPLATES.BROWSER.ERROR') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ loadError }}
          </p>
          <Button size="sm" @click="loadTemplates">
            {{ t('AGENT_BOTS.TEMPLATES.BROWSER.RETRY') }}
          </Button>
        </div>
      </div>

      <!-- Templates Grid -->
      <div v-else class="flex-1 overflow-y-auto">
        <div
          v-if="filteredTemplates.length === 0"
          class="flex items-center justify-center h-full"
        >
          <p class="text-sm text-n-slate-11">
            {{ t('AGENT_BOTS.TEMPLATES.BROWSER.NO_TEMPLATES') }}
          </p>
        </div>
        <div v-else class="grid grid-cols-2 gap-4">
          <button
            v-for="template in filteredTemplates"
            :key="template.id"
            class="flex flex-col gap-3 p-4 rounded-lg border-2 transition-all text-left"
            :class="[
              selectedTemplate?.id === template.id
                ? 'border-n-blue-9 bg-n-blue-2'
                : 'border-n-slate-6 hover:border-n-slate-8 bg-white',
            ]"
            @click="selectTemplate(template)"
          >
            <div class="flex items-start gap-3">
              <div
                class="flex items-center justify-center w-10 h-10 rounded-lg bg-n-slate-3"
              >
                <i class="w-5 h-5 text-n-slate-11" :class="[template.icon]" />
              </div>
              <div class="flex-1 min-w-0">
                <h4 class="text-sm font-medium text-n-slate-12 truncate">
                  {{ template.name }}
                </h4>
                <p class="text-xs text-n-slate-11 line-clamp-2 mt-1">
                  {{ template.description }}
                </p>
              </div>
            </div>
            <div class="flex gap-4 text-xs text-n-slate-11">
              <span class="flex items-center gap-1">
                <i class="i-lucide-circle-dot w-3 h-3" />
                {{ template.preview.nodes }}
                {{ t('AGENT_BOTS.TEMPLATES.BROWSER.NODES') }}
              </span>
              <span class="flex items-center gap-1">
                <i class="i-lucide-arrow-right w-3 h-3" />
                {{ template.preview.connections }}
                {{ t('AGENT_BOTS.TEMPLATES.BROWSER.CONNECTIONS') }}
              </span>
            </div>
          </button>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button variant="tertiary" @click="close">
          {{ t('CANCEL') }}
        </Button>
        <Button
          :disabled="!selectedTemplate"
          variant="primary"
          @click="insertTemplate"
        >
          {{ t('AGENT_BOTS.TEMPLATES.BROWSER.INSERT') }}
        </Button>
      </div>
    </template>
  </Dialog>
</template>
