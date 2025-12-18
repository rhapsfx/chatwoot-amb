<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useHandlerMethods } from '../composables/useHandlerMethods';

const props = defineProps({
  botId: {
    type: Number,
    required: true,
  },
  serviceName: {
    type: String,
    default: null,
  },
  handlerType: {
    type: String,
    default: null,
    validator: value =>
      ['state', 'keyword', 'interactive', 'action'].includes(value) ||
      value === null,
  },
});

const emit = defineEmits(['handlerSelected']);

const { t } = useI18n();

const dialogRef = ref(null);
const searchQuery = ref('');
const selectedHandler = ref(null);
const previewHandler = ref(null);

// Filters
const filterHandlerType = ref(props.handlerType || 'all');
const filterCategory = ref('all');
const filterStatus = ref('all');
const sortBy = ref('alphabetical'); // alphabetical, type, status

// Initialize composable
const {
  handlers,
  meta,
  isLoading,
  error,
  fetchHandlers,
  searchHandlers,
  fetchHandlerDetails,
} = useHandlerMethods(props.botId, props.serviceName);

// Search results (when searching)
const searchResults = ref([]);
const isSearching = ref(false);

// Helper functions (defined before computed properties that use them)

/**
 * Get icon for handler type
 */
function getHandlerTypeIcon(type) {
  const iconMap = {
    state: 'i-lucide-circle-dot',
    keyword: 'i-lucide-message-square',
    interactive: 'i-lucide-touch',
    action: 'i-lucide-zap',
  };
  return iconMap[type] || 'i-lucide-box';
}

/**
 * Get badge color for status
 */
function getStatusColor(status) {
  const colorMap = {
    stable: 'bg-teal-100 text-teal-800',
    experimental: 'bg-amber-100 text-amber-800',
    deprecated: 'bg-ruby-100 text-ruby-800',
  };
  return colorMap[status] || 'bg-n-slate-2 text-n-slate-11';
}

/**
 * Sort handlers based on current sort option
 */
function sortHandlers(items) {
  const sorted = [...items];

  switch (sortBy.value) {
    case 'alphabetical':
      return sorted.sort((a, b) =>
        (a.display_name || a.method_name).localeCompare(
          b.display_name || b.method_name
        )
      );
    case 'type':
      return sorted.sort((a, b) =>
        a.handler_type.localeCompare(b.handler_type)
      );
    case 'status':
      return sorted.sort((a, b) => {
        const statusOrder = { stable: 0, experimental: 1, deprecated: 2 };
        return (statusOrder[a.status] || 3) - (statusOrder[b.status] || 3);
      });
    default:
      return sorted;
  }
}

// Computed properties

/**
 * Available handler types from metadata
 */
const handlerTypes = computed(() => [
  {
    value: 'all',
    label: t('AGENT_BOTS.HANDLER_METHODS.BROWSER.ALL_TYPES'),
    icon: 'i-lucide-layers',
  },
  ...(meta.value.handler_types || []).map(type => ({
    value: type,
    label: t(`AGENT_BOTS.HANDLER_TYPES.${type.toUpperCase()}`) || type,
    icon: getHandlerTypeIcon(type),
  })),
]);

/**
 * Available categories from metadata
 */
const categories = computed(() => [
  {
    value: 'all',
    label: t('AGENT_BOTS.HANDLER_METHODS.CATEGORIES.ALL'),
    icon: 'i-lucide-folder',
  },
  ...(meta.value.categories || []).map(category => ({
    value: category,
    label:
      t(`AGENT_BOTS.HANDLER_CATEGORIES.${category.toUpperCase()}`) || category,
    icon: 'i-lucide-tag',
  })),
]);

/**
 * Status options
 */
const statusOptions = computed(() => [
  {
    value: 'all',
    label: t('AGENT_BOTS.HANDLER_METHODS.BROWSER.ALL_STATUS'),
  },
  {
    value: 'stable',
    label: t('AGENT_BOTS.HANDLER_METHODS.STATUS.STABLE'),
  },
  {
    value: 'experimental',
    label: t('AGENT_BOTS.HANDLER_METHODS.STATUS.EXPERIMENTAL'),
  },
  {
    value: 'deprecated',
    label: t('AGENT_BOTS.HANDLER_METHODS.STATUS.DEPRECATED'),
  },
]);

/**
 * Filtered and sorted handlers
 */
const filteredHandlers = computed(() => {
  let items = isSearching.value ? searchResults.value : handlers.value;

  // Apply filters
  if (filterHandlerType.value !== 'all') {
    items = items.filter(h => h.handler_type === filterHandlerType.value);
  }

  if (filterCategory.value !== 'all') {
    items = items.filter(h => h.category === filterCategory.value);
  }

  if (filterStatus.value !== 'all') {
    items = items.filter(h => h.status === filterStatus.value);
  }

  // Apply sorting
  return sortHandlers(items);
});

/**
 * Grouped handlers by category
 */
const groupedHandlers = computed(() => {
  const groups = {};

  filteredHandlers.value.forEach(handler => {
    const category = handler.category || 'uncategorized';
    if (!groups[category]) {
      groups[category] = [];
    }
    groups[category].push(handler);
  });

  return Object.entries(groups).map(([category, items]) => ({
    category,
    label:
      t(`AGENT_BOTS.HANDLER_CATEGORIES.${category.toUpperCase()}`) || category,
    items,
  }));
});

/**
 * Check if any filters are active
 */
const hasActiveFilters = computed(() => {
  return (
    filterHandlerType.value !== 'all' ||
    filterCategory.value !== 'all' ||
    filterStatus.value !== 'all' ||
    searchQuery.value.trim() !== ''
  );
});

// Methods

/**
 * Debounced search function
 */
const performSearch = useDebounceFn(async query => {
  if (!query.trim()) {
    isSearching.value = false;
    searchResults.value = [];
    return;
  }

  isSearching.value = true;

  try {
    const results = await searchHandlers(query, {
      handler_type:
        filterHandlerType.value !== 'all' ? filterHandlerType.value : undefined,
      limit: 50,
    });
    searchResults.value = results;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[HandlerBrowser] Search error:', err);
  }
}, 300);

/**
 * Load handlers list
 */
async function loadHandlers() {
  try {
    await fetchHandlers({
      handler_type: props.handlerType || undefined,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[HandlerBrowser] Load error:', err);
  }
}

/**
 * Select handler
 */
function selectHandler(handler) {
  selectedHandler.value = handler;
}

/**
 * Preview handler (load full details)
 */
async function previewHandlerDetails(handler) {
  try {
    const details = await fetchHandlerDetails(handler.method_name);
    previewHandler.value = details;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[HandlerBrowser] Preview error:', err);
  }
}

/**
 * Clear preview
 */
function clearPreview() {
  previewHandler.value = null;
}

/**
 * Clear all filters
 */
function clearFilters() {
  filterHandlerType.value = props.handlerType || 'all';
  filterCategory.value = 'all';
  filterStatus.value = 'all';
  searchQuery.value = '';
  isSearching.value = false;
  searchResults.value = [];
}

/**
 * Close dialog
 */
function close() {
  dialogRef.value?.close();
  selectedHandler.value = null;
  previewHandler.value = null;
  clearFilters();
}

/**
 * Confirm selection and emit
 */
function confirmSelection() {
  if (!selectedHandler.value) return;

  emit('handlerSelected', selectedHandler.value);
  close();
}

/**
 * Open dialog
 */
function open() {
  dialogRef.value?.open();
  loadHandlers();
}

/**
 * Handle keyboard shortcuts
 */
function handleKeydown(event) {
  if (event.key === 'Escape') {
    close();
  } else if (event.key === 'Enter' && selectedHandler.value) {
    confirmSelection();
  }
}

// Watchers

watch(searchQuery, query => {
  performSearch(query);
});

// Lifecycle

onMounted(() => {
  window.addEventListener('keydown', handleKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeydown);
});

// Expose methods
defineExpose({
  open,
  close,
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('AGENT_BOTS.HANDLER_METHODS.BROWSER.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="3xl"
    overflow-y-auto
    @close="close"
  >
    <div class="flex flex-col gap-4 min-h-[600px]">
      <!-- Description -->
      <p class="text-sm text-n-slate-11">
        {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.DESCRIPTION') }}
      </p>

      <!-- Search Bar -->
      <div class="relative">
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="
            t('AGENT_BOTS.HANDLER_METHODS.BROWSER.SEARCH_PLACEHOLDER')
          "
          class="w-full px-4 py-2 pl-10 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8 focus:border-transparent"
        />
        <i
          class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-n-slate-11"
        />
        <button
          v-if="searchQuery"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-n-slate-11 hover:text-n-slate-12"
          @click="searchQuery = ''"
        >
          <i class="i-lucide-x w-4 h-4" />
        </button>
      </div>

      <div class="flex gap-4">
        <!-- Filter Sidebar -->
        <div class="w-64 flex-shrink-0 space-y-4">
          <!-- Handler Type Filter -->
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-2 block">{{
              t('AGENT_BOTS.HANDLER_METHODS.FILTERS.HANDLER_TYPE')
            }}</label>
            <div class="space-y-1">
              <button
                v-for="type in handlerTypes"
                :key="type.value"
                class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all"
                :class="[
                  filterHandlerType === type.value
                    ? 'bg-n-blue-8 text-white'
                    : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3',
                ]"
                @click="filterHandlerType = type.value"
              >
                <i class="w-4 h-4" :class="[type.icon]" />
                <span>{{ type.label }}</span>
              </button>
            </div>
          </div>

          <!-- Category Filter -->
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-2 block">{{
              t('AGENT_BOTS.HANDLER_METHODS.FILTERS.CATEGORY')
            }}</label>
            <div class="space-y-1">
              <button
                v-for="category in categories"
                :key="category.value"
                class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all"
                :class="[
                  filterCategory === category.value
                    ? 'bg-n-blue-8 text-white'
                    : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3',
                ]"
                @click="filterCategory = category.value"
              >
                <i class="w-4 h-4" :class="[category.icon]" />
                <span>{{ category.label }}</span>
              </button>
            </div>
          </div>

          <!-- Status Filter -->
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-2 block">{{
              t('AGENT_BOTS.HANDLER_METHODS.FILTERS.STATUS')
            }}</label>
            <div class="space-y-1">
              <button
                v-for="status in statusOptions"
                :key="status.value"
                class="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all"
                :class="[
                  filterStatus === status.value
                    ? 'bg-n-blue-8 text-white'
                    : 'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3',
                ]"
                @click="filterStatus = status.value"
              >
                <span>{{ status.label }}</span>
              </button>
            </div>
          </div>

          <!-- Sort Options -->
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-2 block">{{
              t('AGENT_BOTS.HANDLER_METHODS.BROWSER.SORT_BY')
            }}</label>
            <select
              v-model="sortBy"
              class="w-full px-3 py-2 border border-n-weak rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-n-blue-8"
            >
              <option value="alphabetical">
                {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.SORT_ALPHABETICAL') }}
              </option>
              <option value="type">
                {{ t('AGENT_BOTS.HANDLER_METHODS.FILTERS.HANDLER_TYPE') }}
              </option>
              <option value="status">
                {{ t('AGENT_BOTS.HANDLER_METHODS.FILTERS.STATUS') }}
              </option>
            </select>
          </div>

          <!-- Clear Filters -->
          <button
            v-if="hasActiveFilters"
            class="w-full px-3 py-2 text-sm text-n-blue-11 hover:text-n-blue-12 font-medium"
            @click="clearFilters"
          >
            {{ t('AGENT_BOTS.HANDLER_METHODS.FILTERS.CLEAR_FILTERS') }}
          </button>
        </div>

        <!-- Main Content Area -->
        <div class="flex-1 min-w-0">
          <!-- Loading State -->
          <div
            v-if="isLoading && !handlers.length"
            class="flex flex-col items-center justify-center py-12"
          >
            <i
              class="i-lucide-loader-2 w-8 h-8 mb-3 text-n-slate-8 animate-spin"
            />
            <p class="text-sm text-n-slate-11">
              {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.LOADING_HANDLERS') }}
            </p>
          </div>

          <!-- Error State -->
          <div
            v-else-if="error"
            class="flex flex-col items-center justify-center py-12 text-center"
          >
            <i class="i-lucide-alert-circle w-12 h-12 mb-3 text-ruby-8" />
            <p class="text-sm text-ruby-11 font-medium">{{ error }}</p>
            <button
              class="mt-4 px-4 py-2 text-sm text-n-blue-11 hover:text-n-blue-12 font-medium"
              @click="loadHandlers"
            >
              {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.RETRY') }}
            </button>
          </div>

          <!-- Empty State -->
          <div
            v-else-if="filteredHandlers.length === 0"
            class="flex flex-col items-center justify-center py-12 text-center"
          >
            <i class="i-lucide-search-x w-12 h-12 mb-3 text-n-slate-8" />
            <p class="text-sm text-n-slate-11">
              {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.NO_HANDLERS_FOUND') }}
            </p>
            <button
              v-if="hasActiveFilters"
              class="mt-4 px-4 py-2 text-sm text-n-blue-11 hover:text-n-blue-12 font-medium"
              @click="clearFilters"
            >
              {{ t('AGENT_BOTS.HANDLER_METHODS.BROWSER.CLEAR_FILTERS_BUTTON') }}
            </button>
          </div>

          <!-- Handlers List (Grouped by Category) -->
          <div v-else class="space-y-6">
            <div v-for="group in groupedHandlers" :key="group.category">
              <!-- Category Header -->
              <div class="flex items-center gap-2 mb-3">
                <i class="i-lucide-folder w-4 h-4 text-n-slate-11" />
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ group.label }}
                </h3>
                <span class="text-xs text-n-slate-11"
                  >({{ group.items.length }})</span
                >
              </div>

              <!-- Handler Items -->
              <div class="grid grid-cols-1 gap-2">
                <button
                  v-for="handler in group.items"
                  :key="handler.method_name"
                  class="flex items-start gap-3 p-3 rounded-lg border text-left transition-all group"
                  :class="[
                    selectedHandler?.method_name === handler.method_name
                      ? 'border-n-blue-8 bg-n-blue-1'
                      : 'border-n-weak hover:border-n-strong bg-n-white',
                  ]"
                  @click="selectHandler(handler)"
                  @mouseenter="previewHandlerDetails(handler)"
                  @mouseleave="clearPreview"
                >
                  <!-- Icon -->
                  <div
                    class="flex items-center justify-center w-10 h-10 rounded-lg flex-shrink-0 transition-colors"
                    :class="[
                      selectedHandler?.method_name === handler.method_name
                        ? 'bg-n-blue-8 text-white'
                        : 'bg-n-slate-2 text-n-slate-11 group-hover:bg-n-slate-3',
                    ]"
                  >
                    <i
                      class="w-5 h-5"
                      :class="[getHandlerTypeIcon(handler.handler_type)]"
                    />
                  </div>

                  <!-- Content -->
                  <div class="flex-1 min-w-0">
                    <div class="flex items-start justify-between gap-2 mb-1">
                      <h4 class="font-semibold text-n-slate-12 truncate">
                        {{ handler.display_name || handler.method_name }}
                      </h4>
                      <div class="flex items-center gap-1 flex-shrink-0">
                        <!-- Status Badge -->
                        <span
                          class="px-2 py-0.5 text-xs font-medium rounded-full"
                          :class="getStatusColor(handler.status)"
                        >
                          {{ handler.status }}
                        </span>
                      </div>
                    </div>

                    <p class="text-sm text-n-slate-11 mb-2 line-clamp-2">
                      {{ handler.description }}
                    </p>

                    <!-- Meta Info -->
                    <div
                      class="flex items-center gap-3 text-xs text-n-slate-11"
                    >
                      <div class="flex items-center gap-1">
                        <i class="i-lucide-code w-3 h-3" />
                        <span>{{ handler.method_name }}</span>
                      </div>
                      <div
                        v-if="handler.triggers_count"
                        class="flex items-center gap-1"
                      >
                        <i class="i-lucide-zap w-3 h-3" />
                        <span
                          >{{ handler.triggers_count }}
                          {{
                            t(
                              'AGENT_BOTS.HANDLER_METHODS.BROWSER.TRIGGERS_SUFFIX'
                            )
                          }}</span
                        >
                      </div>
                      <div
                        v-if="handler.dependencies_count"
                        class="flex items-center gap-1"
                      >
                        <i class="i-lucide-link w-3 h-3" />
                        <span
                          >{{ handler.dependencies_count }}
                          {{
                            t(
                              'AGENT_BOTS.HANDLER_METHODS.BROWSER.DEPENDENCIES_SUFFIX'
                            )
                          }}</span
                        >
                      </div>
                      <!-- Search Match Score -->
                      <div
                        v-if="isSearching && handler.match_score"
                        class="flex items-center gap-1"
                      >
                        <i class="i-lucide-target w-3 h-3" />
                        <span
                          >{{ Math.round(handler.match_score * 100) }}%
                          {{
                            t('AGENT_BOTS.HANDLER_METHODS.BROWSER.MATCH_SUFFIX')
                          }}</span
                        >
                      </div>
                    </div>

                    <!-- Search Match Reason -->
                    <div
                      v-if="isSearching && handler.match_reason"
                      class="mt-2 text-xs text-n-blue-11 italic"
                    >
                      {{ handler.match_reason }}
                    </div>
                  </div>

                  <!-- Selected Indicator -->
                  <i
                    v-if="selectedHandler?.method_name === handler.method_name"
                    class="i-lucide-check-circle w-5 h-5 text-n-blue-8 flex-shrink-0"
                  />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Preview Panel (Optional) -->
        <div
          v-if="previewHandler"
          class="w-80 flex-shrink-0 border-l border-n-weak pl-4"
        >
          <div class="sticky top-4 space-y-4">
            <div class="flex items-start justify-between">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('AGENT_BOTS.HANDLER_METHODS.DETAILS.TITLE') }}
              </h3>
              <button
                class="text-n-slate-11 hover:text-n-slate-12"
                @click="clearPreview"
              >
                <i class="i-lucide-x w-4 h-4" />
              </button>
            </div>

            <div class="space-y-3">
              <!-- Method Name -->
              <div>
                <label
                  class="text-xs text-n-slate-11 uppercase tracking-wide"
                  >{{
                    t('AGENT_BOTS.HANDLER_METHODS.BROWSER.METHOD_LABEL')
                  }}</label
                >
                <p class="text-sm text-n-slate-12 font-mono mt-1">
                  {{ previewHandler.method_name }}
                </p>
              </div>

              <!-- Triggers -->
              <div v-if="previewHandler.triggers">
                <label
                  class="text-xs text-n-slate-11 uppercase tracking-wide"
                  >{{ t('AGENT_BOTS.HANDLER_METHODS.DETAILS.TRIGGERS') }}</label
                >
                <div class="mt-1 space-y-1 text-xs">
                  <div v-if="previewHandler.triggers.state_ids?.length">
                    <span class="text-n-slate-11">{{
                      t('AGENT_BOTS.HANDLER_METHODS.BROWSER.STATES_LABEL')
                    }}</span>
                    <span class="text-n-slate-12 font-mono ml-1">
                      {{ previewHandler.triggers.state_ids.join(', ') }}
                    </span>
                  </div>
                  <div v-if="previewHandler.triggers.keywords?.length">
                    <span class="text-n-slate-11">{{
                      t('AGENT_BOTS.HANDLER_METHODS.BROWSER.KEYWORDS_LABEL')
                    }}</span>
                    <span class="text-n-slate-12 ml-1">
                      {{ previewHandler.triggers.keywords.join(', ') }}
                    </span>
                  </div>
                  <div v-if="previewHandler.triggers.interactive_ids?.length">
                    <span class="text-n-slate-11">{{
                      t(
                        'AGENT_BOTS.HANDLER_METHODS.BROWSER.INTERACTIVE_IDS_LABEL'
                      )
                    }}</span>
                    <span class="text-n-slate-12 font-mono ml-1">
                      {{ previewHandler.triggers.interactive_ids.join(', ') }}
                    </span>
                  </div>
                </div>
              </div>

              <!-- Dependencies -->
              <div v-if="previewHandler.dependencies">
                <label
                  class="text-xs text-n-slate-11 uppercase tracking-wide"
                  >{{
                    t('AGENT_BOTS.HANDLER_METHODS.DETAILS.DEPENDENCIES')
                  }}</label
                >
                <div class="mt-1 space-y-1 text-xs">
                  <div v-if="previewHandler.dependencies.templates?.length">
                    <span class="text-n-slate-11">{{
                      t('AGENT_BOTS.HANDLER_METHODS.BROWSER.TEMPLATES_LABEL')
                    }}</span>
                    <span class="text-n-slate-12 ml-1">
                      {{ previewHandler.dependencies.templates.join(', ') }}
                    </span>
                  </div>
                  <div v-if="previewHandler.dependencies.attributes?.length">
                    <span class="text-n-slate-11">{{
                      t('AGENT_BOTS.HANDLER_METHODS.BROWSER.ATTRIBUTES_LABEL')
                    }}</span>
                    <span class="text-n-slate-12 ml-1">
                      {{ previewHandler.dependencies.attributes.join(', ') }}
                    </span>
                  </div>
                  <div v-if="previewHandler.dependencies.services?.length">
                    <span class="text-n-slate-11">{{
                      t('AGENT_BOTS.HANDLER_METHODS.BROWSER.SERVICES_LABEL')
                    }}</span>
                    <span class="text-n-slate-12 ml-1">
                      {{ previewHandler.dependencies.services.join(', ') }}
                    </span>
                  </div>
                </div>
              </div>

              <!-- Tags -->
              <div v-if="previewHandler.tags?.length">
                <label
                  class="text-xs text-n-slate-11 uppercase tracking-wide"
                  >{{ t('AGENT_BOTS.HANDLER_METHODS.DETAILS.TAGS') }}</label
                >
                <div class="flex flex-wrap gap-1 mt-1">
                  <span
                    v-for="tag in previewHandler.tags"
                    :key="tag"
                    class="px-2 py-0.5 text-xs bg-n-slate-2 text-n-slate-11 rounded"
                  >
                    {{ tag }}
                  </span>
                </div>
              </div>

              <!-- Source Location -->
              <div v-if="previewHandler.source_file">
                <label
                  class="text-xs text-n-slate-11 uppercase tracking-wide"
                  >{{ t('AGENT_BOTS.HANDLER_METHODS.DETAILS.SOURCE') }}</label
                >
                <p class="text-xs text-n-slate-12 font-mono mt-1 break-all">
                  {{ previewHandler.source_file }}:{{
                    previewHandler.source_line
                  }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer Actions -->
      <div
        class="flex justify-between items-center pt-4 border-t border-n-weak"
      >
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <i class="i-lucide-info w-4 h-4" />
          <span>
            {{
              t('AGENT_BOTS.HANDLER_METHODS.BROWSER.HANDLERS_SHOWN', {
                count: isSearching
                  ? searchResults.length
                  : filteredHandlers.length,
              })
            }}
            <template v-if="meta.total">
              {{
                t('AGENT_BOTS.HANDLER_METHODS.BROWSER.OF_TOTAL', {
                  total: meta.total,
                })
              }}
            </template>
          </span>
        </div>
        <div class="flex gap-2">
          <Button
            faded
            slate
            :label="t('AGENT_BOTS.HANDLER_METHODS.BROWSER.CANCEL')"
            @click="close"
          />
          <Button
            :label="
              t('AGENT_BOTS.HANDLER_METHODS.BROWSER.SELECT_HANDLER_BUTTON')
            "
            :disabled="!selectedHandler"
            @click="confirmSelection"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
