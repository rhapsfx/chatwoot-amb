<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from 'axios';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  accountId: { type: Number, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

// State
const timePickerTemplates = ref([]);
const loading = ref(false);
const errorMessage = ref('');

// Load time picker templates
onMounted(async () => {
  await loadTemplates();
});

const loadTemplates = async () => {
  loading.value = true;
  errorMessage.value = '';

  try {
    const response = await axios.get(
      `/api/v1/accounts/${props.accountId}/templates`,
      {
        params: {
          category: 'scheduling',
          status: 'active',
          per_page: 100,
        },
      }
    );

    // Filter templates by checking for time_picker content
    timePickerTemplates.value = (response.data.templates || []).filter(
      template => {
        const content = template.content || {};
        const attrs =
          content.contentAttributes || content.content_attributes || {};
        return (
          (attrs.event !== undefined && attrs.event?.timeslots !== undefined) ||
          template.supportedChannels?.includes('apple_messages_for_business')
        );
      }
    );

    if (timePickerTemplates.value.length === 0) {
      errorMessage.value = t(
        'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.NO_TEMPLATES'
      );
    }
  } catch (error) {
    console.error('Failed to load time picker templates:', error);
    errorMessage.value = t(
      'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.ERROR_LOADING'
    );
  } finally {
    loading.value = false;
  }
};

// Two-way binding
const templateId = computed({
  get: () => props.modelValue.template_id || null,
  set: value => {
    emit('update:modelValue', { ...props.modelValue, template_id: value });
  },
});

// Timezone helper - convert hours to seconds
const timezoneHours = computed({
  get: () => {
    const seconds = props.modelValue.timezone_offset || 0;
    return seconds / 3600;
  },
  set: hours => {
    const seconds = Math.round(hours * 3600);
    emit('update:modelValue', {
      ...props.modelValue,
      timezone_offset: seconds,
    });
  },
});

const timezoneOffsetSeconds = computed(() => {
  return props.modelValue.timezone_offset || 0;
});

// Location data bindings
const locationName = computed({
  get: () => props.modelValue.location_data?.name || '',
  set: value => {
    const locationData = { ...props.modelValue.location_data, name: value };
    emit('update:modelValue', {
      ...props.modelValue,
      location_data: locationData,
    });
  },
});

const locationLatitude = computed({
  get: () => props.modelValue.location_data?.latitude || null,
  set: value => {
    const locationData = { ...props.modelValue.location_data, latitude: value };
    emit('update:modelValue', {
      ...props.modelValue,
      location_data: locationData,
    });
  },
});

const locationLongitude = computed({
  get: () => props.modelValue.location_data?.longitude || null,
  set: value => {
    const locationData = {
      ...props.modelValue.location_data,
      longitude: value,
    };
    emit('update:modelValue', {
      ...props.modelValue,
      location_data: locationData,
    });
  },
});

const selectedTemplate = computed(() => {
  if (!templateId.value) return null;
  return timePickerTemplates.value.find(t => t.id === templateId.value);
});
</script>

<template>
  <div class="space-y-4">
    <!-- Template Selector -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.TEMPLATE'
          )
        }}
        *
      </label>

      <!-- Loading State -->
      <div
        v-if="loading"
        class="w-full px-4 py-3 border border-n-weak rounded-lg bg-n-slate-1 text-sm text-n-slate-11"
      >
        <i class="i-lucide-loader-2 w-4 h-4 inline-block animate-spin mr-2" />
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.LOADING'
          )
        }}
      </div>

      <!-- Error State -->
      <div
        v-else-if="errorMessage"
        class="w-full px-4 py-3 border border-red-200 rounded-lg bg-red-50 text-sm text-red-700"
      >
        <i class="i-lucide-alert-circle w-4 h-4 inline-block mr-2" />
        {{ errorMessage }}
        <button
          class="ml-2 underline hover:no-underline"
          @click="loadTemplates"
        >
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.RETRY'
            )
          }}
        </button>
      </div>

      <!-- Template Dropdown -->
      <select
        v-else
        v-model="templateId"
        class="w-full px-4 py-2 pr-8 border border-n-weak rounded-lg bg-n-white text-n-slate-12 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 16 16%27 fill=%27%23666%27%3E%3Cpath d=%27M4.5 5.5l3.5 3.5 3.5-3.5h-7z%27/%3E%3C/svg%3E')] bg-[length:0.875rem] bg-[right_0.5rem_center] bg-no-repeat focus:outline-none focus:ring-2 focus:ring-n-blue-8"
      >
        <option :value="null">
          {{
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.SELECT_TEMPLATE'
            )
          }}
        </option>
        <option
          v-for="template in timePickerTemplates"
          :key="template.id"
          :value="template.id"
        >
          {{ template.name }}
        </option>
      </select>

      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.TEMPLATE_HELP'
          )
        }}
      </p>

      <!-- Template Preview -->
      <div
        v-if="selectedTemplate"
        class="mt-2 p-3 bg-n-slate-1 border border-n-weak rounded-lg"
      >
        <div class="flex items-start gap-2">
          <i class="i-lucide-check-circle w-4 h-4 text-green-600 mt-0.5" />
          <div class="flex-1">
            <p class="text-sm font-medium text-n-slate-12">
              {{ selectedTemplate.name }}
            </p>
            <p
              v-if="selectedTemplate.description"
              class="text-xs text-n-slate-11 mt-1"
            >
              {{ selectedTemplate.description }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Timezone Offset -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.TIMEZONE_OFFSET'
          )
        }}
      </label>
      <div class="flex gap-2 items-center">
        <input
          v-model.number="timezoneHours"
          type="number"
          min="-12"
          max="14"
          step="0.5"
          :placeholder="
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.TIMEZONE_PLACEHOLDER'
            )
          "
          class="flex-1 px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        />
        <div
          class="px-4 py-2 bg-n-slate-2 border border-n-weak rounded-lg text-sm text-n-slate-11 min-w-[100px] text-center"
        >
          {{ timezoneOffsetSeconds }}s
        </div>
      </div>
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.TIMEZONE_HELP'
          )
        }}
      </p>
    </div>

    <!-- Location Data (Optional) -->
    <div>
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.LOCATION'
          )
        }}
      </label>
      <div class="space-y-2">
        <input
          v-model="locationName"
          type="text"
          :placeholder="
            t(
              'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.LOCATION_NAME_PLACEHOLDER'
            )
          "
          class="w-full px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
        />
        <div class="grid grid-cols-2 gap-2">
          <input
            v-model.number="locationLatitude"
            type="number"
            step="0.000001"
            :placeholder="
              t(
                'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.LATITUDE_PLACEHOLDER'
              )
            "
            class="px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
          />
          <input
            v-model.number="locationLongitude"
            type="number"
            step="0.000001"
            :placeholder="
              t(
                'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.LONGITUDE_PLACEHOLDER'
              )
            "
            class="px-4 py-2 border border-n-weak rounded-lg focus:outline-none focus:ring-2 focus:ring-n-blue-8"
          />
        </div>
      </div>
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t(
            'AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES.TYPES.SEND_TIME_PICKER.PARAMETERS.LOCATION_HELP'
          )
        }}
      </p>
    </div>
  </div>
</template>
