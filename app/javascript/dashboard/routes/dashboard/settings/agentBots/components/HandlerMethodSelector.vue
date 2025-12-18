<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { getAxios } from 'dashboard/helper/axios';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  botId: {
    type: Number,
    required: true,
  },
  serviceName: {
    type: String,
    default: '',
  },
  handlerType: {
    type: String,
    default: '',
  },
  required: {
    type: Boolean,
    default: false,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue', 'handlerSelected']);

const { t } = useI18n();
const currentAccountId = useMapGetter('getCurrentAccountId');

// Local state
const searchQuery = ref('');
const isOpen = ref(false);
const loading = ref(false);
const searchResults = ref([]);
const selectedHandlerDetails = ref(null);
const validationError = ref('');
const inputRef = ref(null);
const dropdownRef = ref(null);
const selectedIndex = ref(-1);
const debounceTimer = ref(null);

// Computed
const displayValue = computed(() => {
  return props.modelValue || searchQuery.value;
});

const filteredResults = computed(() => {
  if (!searchQuery.value) return [];
  return searchResults.value;
});

const hasError = computed(() => {
  return !!validationError.value;
});

const errorMessage = computed(() => {
  return validationError.value || '';
});

// Methods
const searchHandlers = async query => {
  if (!query || query.length < 2) {
    searchResults.value = [];
    return;
  }

  loading.value = true;
  validationError.value = '';

  try {
    const params = {
      q: query,
      limit: 20,
    };

    if (props.serviceName) {
      params.service_name = props.serviceName;
    }

    if (props.handlerType) {
      params.handler_type = props.handlerType;
    }

    const url = `/api/v1/accounts/${currentAccountId.value}/agent_bots/${props.botId}/handler_methods/search`;
    const response = await getAxios().get(url, { params });

    searchResults.value = response.data.results || [];
  } catch (error) {
    // Error logging removed per linting rules
    validationError.value = t('AGENT_BOTS.HANDLER_SELECTOR.SEARCH_ERROR');
    searchResults.value = [];
  } finally {
    loading.value = false;
  }
};

const debouncedSearch = query => {
  if (debounceTimer.value) {
    clearTimeout(debounceTimer.value);
  }

  debounceTimer.value = setTimeout(() => {
    searchHandlers(query);
  }, 300);
};

const handleInput = event => {
  const value = event.target.value;
  searchQuery.value = value;
  emit('update:modelValue', value);

  if (value.length >= 2) {
    isOpen.value = true;
    debouncedSearch(value);
  } else {
    isOpen.value = false;
    searchResults.value = [];
  }

  selectedIndex.value = -1;
  validationError.value = '';
};

const handleFocus = () => {
  if (searchQuery.value.length >= 2) {
    isOpen.value = true;
    if (searchResults.value.length === 0) {
      debouncedSearch(searchQuery.value);
    }
  }
};

const selectHandler = handler => {
  searchQuery.value = handler.method_name;
  emit('update:modelValue', handler.method_name);
  emit('handlerSelected', handler);
  selectedHandlerDetails.value = handler;
  isOpen.value = false;
  selectedIndex.value = -1;
  validationError.value = '';
  inputRef.value?.blur();
};

const validateHandler = async () => {
  if (!props.modelValue) {
    if (props.required) {
      validationError.value = t('AGENT_BOTS.HANDLER_SELECTOR.REQUIRED_ERROR');
    }
    return;
  }

  loading.value = true;
  validationError.value = '';

  try {
    const params = {
      method_name: props.modelValue,
    };

    if (props.serviceName) {
      params.service_name = props.serviceName;
    }

    if (props.handlerType) {
      params.handler_type = props.handlerType;
    }

    const url = `/api/v1/accounts/${currentAccountId.value}/agent_bots/${props.botId}/handler_methods/validate`;
    const response = await getAxios().post(url, params);

    if (!response.data.valid) {
      const errors = response.data.errors || [];
      if (errors.length > 0) {
        validationError.value = errors[0].message;
      }
    }
  } catch (error) {
    // Error logging removed per linting rules
    validationError.value = t('AGENT_BOTS.HANDLER_SELECTOR.VALIDATION_ERROR');
  } finally {
    loading.value = false;
  }
};

const closeDropdown = () => {
  isOpen.value = false;
  selectedIndex.value = -1;
};

const scrollToSelected = () => {
  if (selectedIndex.value >= 0 && dropdownRef.value) {
    const selectedEl = dropdownRef.value.children[selectedIndex.value];
    if (selectedEl) {
      selectedEl.scrollIntoView({ block: 'nearest' });
    }
  }
};

const handleKeydown = event => {
  if (!isOpen.value || filteredResults.value.length === 0) return;

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault();
      selectedIndex.value = Math.min(
        selectedIndex.value + 1,
        filteredResults.value.length - 1
      );
      scrollToSelected();
      break;

    case 'ArrowUp':
      event.preventDefault();
      selectedIndex.value = Math.max(selectedIndex.value - 1, 0);
      scrollToSelected();
      break;

    case 'Enter':
      event.preventDefault();
      if (selectedIndex.value >= 0) {
        selectHandler(filteredResults.value[selectedIndex.value]);
      }
      break;

    case 'Escape':
      event.preventDefault();
      closeDropdown();
      inputRef.value?.blur();
      break;

    default:
      // No action needed for other keys
      break;
  }
};

const getHandlerTypeColor = type => {
  switch (type) {
    case 'state':
      return 'text-n-blue-11 bg-n-blue-2';
    case 'keyword':
      return 'text-n-teal-11 bg-n-teal-2';
    case 'interactive':
      return 'text-n-purple-11 bg-n-purple-2';
    case 'action':
      return 'text-n-orange-11 bg-n-orange-2';
    default:
      return 'text-n-slate-11 bg-n-slate-2';
  }
};

const getStatusColor = status => {
  switch (status) {
    case 'stable':
      return 'text-n-teal-11 bg-n-teal-2';
    case 'experimental':
      return 'text-n-orange-11 bg-n-orange-2';
    case 'deprecated':
      return 'text-n-ruby-11 bg-n-ruby-2';
    default:
      return 'text-n-slate-11 bg-n-slate-2';
  }
};

// Watchers
watch(
  () => props.modelValue,
  newValue => {
    if (newValue !== searchQuery.value) {
      searchQuery.value = newValue || '';
    }
  },
  { immediate: true }
);

// Lifecycle
onMounted(() => {
  if (props.modelValue) {
    validateHandler();
  }
});
</script>

<template>
  <div v-on-clickaway="closeDropdown" class="relative handler-method-selector">
    <div class="relative">
      <input
        ref="inputRef"
        :value="displayValue"
        type="text"
        :placeholder="
          t('AGENT_BOTS.HANDLER_SELECTOR.PLACEHOLDER') ||
          'Search handler methods...'
        "
        :disabled="disabled"
        class="block w-full reset-base text-sm !mb-0 outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 h-10 !px-3 !py-2.5 placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10 disabled:cursor-not-allowed disabled:opacity-50 text-n-slate-12 transition-all duration-500 ease-in-out"
        :class="[
          hasError
            ? 'outline-n-ruby-8 dark:outline-n-ruby-8 hover:outline-n-ruby-9 dark:hover:outline-n-ruby-9'
            : 'outline-n-weak dark:outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 focus:outline-n-brand dark:focus:outline-n-brand',
        ]"
        :aria-label="t('AGENT_BOTS.HANDLER_SELECTOR.LABEL')"
        :aria-expanded="isOpen"
        :aria-invalid="hasError"
        role="combobox"
        aria-autocomplete="list"
        autocomplete="off"
        @input="handleInput"
        @focus="handleFocus"
        @keydown="handleKeydown"
        @blur="validateHandler"
      />

      <!-- Loading spinner -->
      <div
        v-if="loading"
        class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none"
      >
        <i class="i-lucide-loader-2 w-4 h-4 text-n-slate-10 animate-spin" />
      </div>

      <!-- Valid icon -->
      <div
        v-else-if="modelValue && !hasError"
        class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none"
      >
        <i class="i-lucide-check-circle w-4 h-4 text-n-teal-9" />
      </div>
    </div>

    <!-- Error message -->
    <p
      v-if="hasError"
      class="min-w-0 mt-1 mb-0 text-xs truncate transition-all duration-500 ease-in-out text-n-ruby-9 dark:text-n-ruby-9"
    >
      {{ errorMessage }}
    </p>

    <!-- Dropdown results -->
    <div
      v-if="isOpen && filteredResults.length > 0"
      class="absolute z-50 w-full mt-1 max-h-96 overflow-y-auto bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak dark:border-n-strong/50 rounded-lg shadow-lg"
    >
      <div ref="dropdownRef" class="py-1">
        <button
          v-for="(handler, index) in filteredResults"
          :key="handler.method_name"
          type="button"
          class="w-full px-3 py-2 text-left hover:bg-n-alpha-2 transition-colors focus:outline-none focus:bg-n-alpha-2"
          :class="[
            index === selectedIndex
              ? 'bg-n-alpha-2'
              : 'bg-transparent hover:bg-n-slate-2',
          ]"
          @click="selectHandler(handler)"
          @mouseenter="selectedIndex = index"
        >
          <div class="flex items-start justify-between gap-2 mb-1">
            <span class="font-mono text-sm font-medium text-n-slate-12">
              {{ handler.method_name }}
            </span>
            <div class="flex items-center gap-1 flex-shrink-0">
              <!-- Handler type badge -->
              <span
                class="px-1.5 py-0.5 text-xs font-medium rounded"
                :class="getHandlerTypeColor(handler.handler_type)"
              >
                {{ handler.handler_type }}
              </span>
              <!-- Status badge -->
              <span
                v-if="handler.status && handler.status !== 'stable'"
                class="px-1.5 py-0.5 text-xs font-medium rounded"
                :class="getStatusColor(handler.status)"
              >
                {{ handler.status }}
              </span>
            </div>
          </div>

          <p class="text-xs text-n-slate-11 mb-1">
            {{ handler.description }}
          </p>

          <!-- Category and match reason -->
          <div class="flex items-center gap-2 text-xs text-n-slate-10">
            <span v-if="handler.category" class="flex items-center gap-1">
              <i class="i-lucide-folder w-3 h-3" />
              {{ handler.category }}
            </span>
            <span
              v-if="handler.match_reason"
              class="flex items-center gap-1 text-n-blue-10"
            >
              <i class="i-lucide-search w-3 h-3" />
              {{ handler.match_reason }}
            </span>
          </div>
        </button>
      </div>
    </div>

    <!-- No results message -->
    <div
      v-if="
        isOpen &&
        !loading &&
        searchQuery.length >= 2 &&
        filteredResults.length === 0
      "
      class="absolute z-50 w-full mt-1 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak dark:border-n-strong/50 rounded-lg shadow-lg"
    >
      <div class="px-3 py-4 text-center">
        <i class="i-lucide-search-x w-8 h-8 mx-auto mb-2 text-n-slate-9" />
        <p class="text-sm text-n-slate-11">
          {{
            t('AGENT_BOTS.HANDLER_SELECTOR.NO_RESULTS') ||
            'No handler methods found'
          }}
        </p>
        <p class="text-xs text-n-slate-10 mt-1">
          {{
            t('AGENT_BOTS.HANDLER_SELECTOR.NO_RESULTS_HINT') ||
            'Try a different search term'
          }}
        </p>
      </div>
    </div>

    <!-- Helper text -->
    <p
      v-if="!hasError && !modelValue"
      class="min-w-0 mt-1 mb-0 text-xs text-n-slate-10"
    >
      {{
        t('AGENT_BOTS.HANDLER_SELECTOR.HELPER_TEXT') ||
        'Type at least 2 characters to search'
      }}
    </p>
  </div>
</template>

<style scoped>
.handler-method-selector {
  /* All styling handled by Tailwind */
}
</style>
