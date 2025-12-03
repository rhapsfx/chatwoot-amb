<!-- eslint-disable no-unused-vars -->
<!-- eslint-disable no-use-before-define -->
<!-- eslint-disable no-plusplus -->
<!-- eslint-disable no-lonely-if -->
<!-- eslint-disable default-case -->
<!-- eslint-disable no-console -->
<!-- eslint-disable no-alert -->
<!-- eslint-disable no-shadow -->
<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<!-- eslint-disable no-template-curly-in-string -->
<!-- eslint-disable prettier/prettier -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

const props = defineProps({
  conversation: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits([
  'send',
  'sendAppleMessage',
  'cancel',
  'saveAsTemplate',
]);

console.log('[AMB] AppleMessagesComposer loading...');

import {
  format,
  addMinutes,
  startOfDay,
  addDays,
  startOfWeek,
  addWeeks,
  subWeeks,
} from 'date-fns';
import { zonedTimeToUtc } from 'date-fns-tz';
import EnhancedTimePickerModal from 'dashboard/components-next/message/modals/EnhancedTimePickerModal.vue';
import AppleFormBuilder from 'dashboard/components-next/message/modals/AppleFormBuilder.vue';
import SaveAsTemplateModal from 'dashboard/components-next/message/modals/SaveAsTemplateModal.vue';
import SharedImageSelector from 'dashboard/routes/dashboard/settings/templates/components/SharedImageSelector.vue';
// Phase 1: Migrating to new apple_amb_images endpoint
import AppleMessagesImagesAPI from 'dashboard/api/appleAmbMessagesImages';
// Old import (kept commented for Phase 1 rollback capability):
// import AppleMessagesImagesAPI from 'dashboard/api/appleMessagesImages';
import TemplateSelector from 'dashboard/components/widgets/conversation/TemplateSelector.vue';

const { t } = useI18n();
const store = useStore();

const activeTab = ref('quick_reply');

// Template selector state
const showTemplateSelector = ref(false);
const templateSearchKey = ref('');

// Automatically open form builder when Forms tab is selected
watch(activeTab, newTab => {
  if (newTab === 'forms') {
    showFormBuilder.value = true;
  }
});

// Saved images from ActiveStorage
const savedImages = ref([]);
const loadingSavedImages = ref(false);

// Image source toggle state for List Picker and Time Picker
const listPickerHeaderImageSource = ref('inline'); // 'inline' or 'shared'
const timePickerImageSource = ref('inline'); // 'inline' or 'shared'

// Form Builder State
const showFormBuilder = ref(false);

// Save As Template Modal State
const showSaveAsTemplateModal = ref(false);
const pendingTemplateData = ref(null);

// iMessage App State
const selectedAppId = ref('');
const selectedAppData = ref({});

// Custom Payload State
const customPayloadData = ref({
  payload: '',
  skipValidation: false,
  applyCaseTransform: false,
});
const sendError = ref(null);
const isSending = ref(false);
const showErrorDetails = ref(false);

// Auto-select first app when switching to iMessage Apps tab
watch(activeTab, newTab => {
  if (newTab === 'imessage_apps' && availableApps.value.length === 1) {
    selectedAppId.value = availableApps.value[0].id;
  }
});

// DEBUG: Watch for changes to listPickerData.sections
watch(
  () => listPickerData.value.sections,
  (newSections, oldSections) => {
    console.log('[DEBUG] listPickerData.sections changed:', {
      newSections: newSections,
      oldSections: oldSections || null,
    });
  },
  { deep: true }
);

// Computed properties
const availableApps = computed(() => {
  const inboxId = props.conversation?.inbox_id;

  if (!inboxId) {
    return [];
  }

  // Get the full inbox data from the store
  const inbox = store.getters['inboxes/getInboxById'](inboxId);

  if (!inbox) {
    return [];
  }

  // Try both possible field names directly on inbox
  const apps = inbox.imessageApps || inbox.imessage_apps || [];

  if (!Array.isArray(apps) || apps.length === 0) {
    return [];
  }

  const enabledApps = apps.filter(app => app.enabled !== false);
  return enabledApps;
});

const selectedApp = computed(() => {
  if (!selectedAppId.value) return null;
  return availableApps.value.find(app => app.id === selectedAppId.value);
});

// Custom Payload Computed Properties
const isValidJson = computed(() => {
  try {
    if (!customPayloadData.value.payload.trim()) return false;
    JSON.parse(customPayloadData.value.payload);
    return true;
  } catch (e) {
    return false;
  }
});

const jsonValidationError = computed(() => {
  try {
    if (!customPayloadData.value.payload.trim()) return '';
    JSON.parse(customPayloadData.value.payload);
    return '';
  } catch (e) {
    return e.message;
  }
});

const previewPayload = computed(() => {
  if (!isValidJson.value) {
    return JSON.stringify(
      {
        v: 1,
        id: '<generated-on-send>',
        sourceId: '<your-business-id>',
        destinationId: '<contact-id>',
        // Your custom payload will appear here after parsing
      },
      null,
      2
    );
  }

  try {
    const parsed = JSON.parse(customPayloadData.value.payload);

    return JSON.stringify(
      {
        v: 1,
        id: '<generated-on-send>',
        sourceId: '<your-business-id>',
        destinationId: '<contact-id>',
        ...parsed,
      },
      null,
      2
    );
  } catch {
    return '{}';
  }
});

// Enhanced Time Picker State
const showEnhancedTimePicker = ref(false);

// Inline Time Picker State
const inlineTimePickerData = ref({
  selectedDate: format(addDays(new Date(), 1), 'yyyy-MM-dd'), // Default to tomorrow
  selectedInterval: 30, // minutes
  useBusinessHours: true,
  customStartTime: '09:00',
  customEndTime: '17:00',
  serviceDuration: 60, // minutes
  maxSlots: 10,
  selectedSlots: [],
});

const selectedSlotIds = ref(new Set());
const currentWeekStart = ref(startOfWeek(new Date()));

// Multi-day selection storage: Map of date -> Set of slot IDs
const multiDaySelections = ref(new Map());

// Global selected slots across all dates with unique keys
const globalSelectedSlots = ref(new Map()); // Map of unique slot key -> slot data

// Business hours configuration - Make sure Friday is enabled
const businessHours = ref({
  monday: { start: '09:00', end: '17:00', enabled: true },
  tuesday: { start: '09:00', end: '17:00', enabled: true },
  wednesday: { start: '09:00', end: '17:00', enabled: true },
  thursday: { start: '09:00', end: '17:00', enabled: true },
  friday: { start: '09:00', end: '17:00', enabled: true }, // Enable Friday
  saturday: { start: '10:00', end: '16:00', enabled: false },
  sunday: { start: '10:00', end: '16:00', enabled: false },
});

// Time interval options
const intervalOptions = [
  { value: 15, label: '15 min', icon: '⏱️' },
  { value: 30, label: '30 min', icon: '🕐' },
  { value: 60, label: '1 hour', icon: '🕑' },
];

// Computed properties for inline time picker
const availableSlots = computed(() => {
  try {
    if (!inlineTimePickerData.value.selectedDate) return [];

    const date = new Date(
      inlineTimePickerData.value.selectedDate + 'T00:00:00'
    );
    const dayName = format(date, 'EEEE').toLowerCase();

    console.log('Generating slots for:', {
      selectedDate: inlineTimePickerData.value.selectedDate,
      dayName,
      useBusinessHours: inlineTimePickerData.value.useBusinessHours,
    });

    // Check if the selected date is in the past
    const today = new Date();
    const selectedDate = new Date(
      inlineTimePickerData.value.selectedDate + 'T00:00:00'
    );
    const isToday = selectedDate.toDateString() === today.toDateString();
    const isPastDate = selectedDate < today && !isToday;

    if (isPastDate) {
      console.log('Date is in the past, no slots generated');
      return [];
    }

    let startTime;
    let endTime;

    if (inlineTimePickerData.value.useBusinessHours) {
      const businessHour = businessHours.value[dayName];
      console.log('Business hour for', dayName, ':', businessHour);

      if (!businessHour?.enabled) {
        console.log('Business day not enabled for', dayName);
        return [];
      }

      // Ensure we have valid start and end times
      const startStr = businessHour.start || '09:00';
      const endStr = businessHour.end || '17:00';

      startTime = new Date(
        `${inlineTimePickerData.value.selectedDate}T${startStr}:00`
      );
      endTime = new Date(
        `${inlineTimePickerData.value.selectedDate}T${endStr}:00`
      );

      console.log('Using business hours:', { start: startStr, end: endStr });
    } else {
      const startStr = inlineTimePickerData.value.customStartTime || '09:00';
      const endStr = inlineTimePickerData.value.customEndTime || '17:00';

      startTime = new Date(
        `${inlineTimePickerData.value.selectedDate}T${startStr}:00`
      );
      endTime = new Date(
        `${inlineTimePickerData.value.selectedDate}T${endStr}:00`
      );

      console.log('Using custom hours:', { start: startStr, end: endStr });
    }

    console.log('Time range:', { startTime, endTime });

    // If it's today, ensure we only show future time slots
    if (isToday) {
      const now = new Date();
      if (startTime <= now) {
        const minutesToAdd =
          inlineTimePickerData.value.selectedInterval -
          (now.getMinutes() % inlineTimePickerData.value.selectedInterval);
        startTime = new Date(now.getTime() + minutesToAdd * 60000);
        startTime.setSeconds(0, 0);
      }
    }

    const slots = [];
    let currentSlot = new Date(startTime);
    let slotId = 0;

    while (currentSlot < endTime) {
      const slotEnd = addMinutes(
        currentSlot,
        inlineTimePickerData.value.serviceDuration
      );

      if (slotEnd <= endTime) {
        const slotKey = `${inlineTimePickerData.value.selectedDate}_${slotId}`;
        const isSelected = globalSelectedSlots.value.has(slotKey);

        slots.push({
          id: slotId.toString(),
          key: slotKey,
          date: inlineTimePickerData.value.selectedDate,
          startTime: new Date(currentSlot),
          endTime: new Date(slotEnd),
          duration: inlineTimePickerData.value.serviceDuration,
          available: true,
          selected: isSelected,
          displayTime: format(currentSlot, 'HH:mm'),
          displayEndTime: format(slotEnd, 'HH:mm'),
          utcTime: zonedTimeToUtc(
            currentSlot,
            Intl.DateTimeFormat().resolvedOptions().timeZone
          )
            .toISOString()
            .replace('Z', '+0000'),
          localTime: format(currentSlot, "yyyy-MM-dd'T'HH:mm:ss"),
        });
      }

      currentSlot = addMinutes(
        currentSlot,
        inlineTimePickerData.value.selectedInterval
      );
      slotId++;
    }

    console.log('Generated slots:', slots.length);
    return slots;
  } catch (error) {
    console.error('Error generating slots:', error);
    return [];
  }
});

const weekDays = computed(() => {
  const startDate = currentWeekStart.value;
  const days = [];

  for (let i = 0; i < 7; i++) {
    const date = addDays(startDate, i);
    const dayName = format(date, 'EEEE').toLowerCase();
    const businessHour = businessHours.value[dayName];

    days.push({
      date: format(date, 'yyyy-MM-dd'),
      displayDate: format(date, 'MMM d'),
      dayName: format(date, 'EEE'),
      isToday: format(date, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd'),
      isSelected:
        format(date, 'yyyy-MM-dd') === inlineTimePickerData.value.selectedDate,
      isBusinessDay: businessHour?.enabled || false,
      hasSlots: !!businessHour?.enabled,
      isPast: date < startOfDay(new Date()),
    });
  }

  return days;
});

const selectedSlotsData = computed(() => {
  // Return all selected slots across all dates, sorted by date and time
  const allSelectedSlots = Array.from(globalSelectedSlots.value.values());
  return allSelectedSlots.sort((a, b) => {
    const dateCompare = a.date.localeCompare(b.date);
    if (dateCompare !== 0) return dateCompare;
    // Use the startTime Date object directly
    return a.startTime.getTime() - b.startTime.getTime();
  });
});

// Methods for inline time picker
const toggleSlot = slot => {
  if (!slot.available) return;

  const slotKey = slot.key;
  const isCurrentlySelected = globalSelectedSlots.value.has(slotKey);

  if (isCurrentlySelected) {
    // Remove slot
    globalSelectedSlots.value.delete(slotKey);
    selectedSlotIds.value.delete(slot.id);

    // Update multi-day selections map
    const dateSelections = multiDaySelections.value.get(slot.date) || new Set();
    dateSelections.delete(slot.id);
    if (dateSelections.size === 0) {
      multiDaySelections.value.delete(slot.date);
    } else {
      multiDaySelections.value.set(slot.date, dateSelections);
    }
  } else {
    // Check max slots limit
    if (globalSelectedSlots.value.size < inlineTimePickerData.value.maxSlots) {
      // Add slot - store the complete slot data for UI display with static date
      const staticSlot = {
        ...slot,
        key: slotKey,
        date: String(slot.date), // Convert to static string to prevent reactivity issues
        startTime: new Date(slot.startTime), // Create new Date object
        endTime: new Date(slot.endTime), // Create new Date object
        displayTime: slot.displayTime,
        displayEndTime: slot.displayEndTime,
        duration: slot.duration,
        utcTime: slot.utcTime,
        localTime: slot.localTime,
        available: slot.available,
        selected: slot.selected,
        id: slot.id,
      };

      globalSelectedSlots.value.set(slotKey, staticSlot);
      selectedSlotIds.value.add(slot.id);

      // Update multi-day selections map
      const dateSelections =
        multiDaySelections.value.get(slot.date) || new Set();
      dateSelections.add(slot.id);
      multiDaySelections.value.set(slot.date, dateSelections);
    }
  }

  updateTimePickerData();
};

const selectDate = dateString => {
  // Save current date selections before switching
  if (
    inlineTimePickerData.value.selectedDate &&
    selectedSlotIds.value.size > 0
  ) {
    multiDaySelections.value.set(
      inlineTimePickerData.value.selectedDate,
      new Set(selectedSlotIds.value)
    );
  }

  // Switch to new date
  inlineTimePickerData.value.selectedDate = dateString;

  // Load selections for the new date
  const dateSelections = multiDaySelections.value.get(dateString) || new Set();
  selectedSlotIds.value = new Set(dateSelections);

  updateTimePickerData();
};

const navigateWeek = direction => {
  if (direction === 'prev') {
    currentWeekStart.value = subWeeks(currentWeekStart.value, 1);
  } else {
    currentWeekStart.value = addWeeks(currentWeekStart.value, 1);
  }
};

const updateTimePickerData = () => {
  // Update formData with all selected slots across all dates for Apple MSP format
  const slots = Array.from(globalSelectedSlots.value.values()).map(slot => ({
    identifier: slot.key,
    startTime: slot.utcTime,
    duration: slot.duration * 60, // Convert to seconds for Apple MSP
  }));

  timePickerData.value.event.timeslots = slots;

  // Debug logging
  console.log('🔥 Inline Time Picker - updateTimePickerData:', {
    globalSelectedSlots: globalSelectedSlots.value.size,
    formattedSlots: slots,
    sampleSlot: slots[0],
    assignedTimeslots: timePickerData.value.event.timeslots,
    timeslotsLength: timePickerData.value.event.timeslots.length,
    // Verify the first slot has startTime
    firstSlotHasStartTime: slots[0]?.startTime !== undefined,
    firstSlotStartTimeValue: slots[0]?.startTime,
  });
};

// Find next available business day
const findNextBusinessDay = () => {
  try {
    let date = new Date();
    date.setDate(date.getDate() + 1); // Start from tomorrow

    for (let i = 0; i < 7; i++) {
      // Check up to 7 days ahead
      const dayName = format(date, 'EEEE').toLowerCase();
      const businessHour = businessHours.value[dayName];

      if (businessHour?.enabled) {
        return format(date, 'yyyy-MM-dd');
      }

      date.setDate(date.getDate() + 1);
    }

    // Fallback to tomorrow if no business days found
    return format(addDays(new Date(), 1), 'yyyy-MM-dd');
  } catch (error) {
    console.error('Error finding next business day:', error);
    // Fallback to tomorrow
    return format(addDays(new Date(), 1), 'yyyy-MM-dd');
  }
};

// Initialize with next business day
const initializeTimePickerDate = () => {
  try {
    // Use the findNextBusinessDay function to get a proper business day
    const nextBusinessDay = findNextBusinessDay();
    inlineTimePickerData.value.selectedDate = nextBusinessDay;

    console.log('Initialized with business day:', nextBusinessDay);
    console.log(
      'Day of week:',
      new Date(nextBusinessDay + 'T00:00:00').toLocaleDateString('en-US', {
        weekday: 'long',
      })
    );
    console.log('Business hours:', businessHours.value);
    console.log(
      'Use business hours:',
      inlineTimePickerData.value.useBusinessHours
    );

    // Force update after a tick to ensure reactive values are set
    setTimeout(() => {
      console.log('Available slots after init:', availableSlots.value.length);
    }, 100);
  } catch (error) {
    console.error('Error initializing time picker date:', error);
    // Fallback to tomorrow
    inlineTimePickerData.value.selectedDate = format(
      addDays(new Date(), 1),
      'yyyy-MM-dd'
    );
  }
};

// Register global handler immediately (not waiting for mount)
window.handleAppleTemplateSelect = null; // Will be set after handleTemplateSelect is defined

// Initialize on component mount
onMounted(() => {
  initializeTimePickerDate();
  loadSavedImages();
  // Load templates
  store.dispatch('messageTemplates/get', {
    channel: 'apple_messages_for_business',
  });

  // Register global handler as workaround for event propagation issues
  if (typeof handleTemplateSelect === 'function') {
    window.handleAppleTemplateSelect = handleTemplateSelect;
    console.log('[AMB Templates] Registered global template handler');
  } else {
    console.error('[AMB Templates] handleTemplateSelect is not a function!');
  }
});

// List Picker State
const listPickerData = ref({
  sections: [
    {
      title: 'Options',
      multipleSelection: false,
      items: [
        {
          identifier: 'option_1',
          title: 'Option 1',
          subtitle: 'Description 1',
        },
        {
          identifier: 'option_2',
          title: 'Option 2',
          subtitle: 'Description 2',
        },
        {
          identifier: 'option_3',
          title: 'Option 3',
          subtitle: 'Description 3',
        },
      ],
    },
  ],
  images: [], // Support for images array
  received_title: 'Please select an option',
  received_subtitle: '',
  received_image_identifier: '', // Support for header image
  received_style: 'icon',
  reply_title: 'Selection Made',
  reply_subtitle: 'Your selection',
  reply_style: 'icon',
  reply_image_title: '',
  reply_image_subtitle: '',
  reply_secondary_subtitle: '',
  reply_tertiary_subtitle: '',
});

// Quick Reply State
const quickReplyData = ref({
  summary_text: 'Quick Reply Question',
  items: [{ title: 'Yes' }, { title: 'No' }],
});

// Time Picker State
const timePickerData = ref({
  event: {
    title: 'Schedule Appointment',
    description: 'Select a time slot',
    timeslots: [
      {
        startTime: new Date('2025-12-15T14:00:00Z').toISOString(), // Future date after Nov 30, 2025
        duration: 60,
      },
      {
        startTime: new Date('2025-12-15T15:00:00Z').toISOString(), // Additional slot
        duration: 60,
      },
    ],
  },
  timezone_offset: -480,
  received_title: 'Please pick a time',
  received_subtitle: 'Select your preferred time slot',
  receivedImageIdentifier: '', // Image for received message
  received_style: 'icon',
  reply_title: 'Thank you!',
  reply_subtitle: '',
  replyImageIdentifier: '', // Image for reply message
  reply_style: 'icon',
  reply_image_title: '',
  reply_image_subtitle: '',
  reply_secondary_subtitle: '',
  reply_tertiary_subtitle: '',
});

// Apple MSP style options
const styleOptions = [
  {
    value: 'icon',
    label: 'Icon',
    dimensions: '280×65',
    description: 'Compact header with small icon',
  },
  {
    value: 'small',
    label: 'Small',
    dimensions: '280×85',
    description: 'Medium-sized header',
  },
  {
    value: 'large',
    label: 'Large',
    dimensions: '280×210',
    description: 'Full-width banner image',
  },
];

// Image management
const addImage = () => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = e => {
    const file = e.target.files[0];
    if (file) {
      // Validate file size (max 5MB for better performance)
      if (file.size > 5 * 1024 * 1024) {
        alert('Image file size must be less than 5MB');
        return;
      }

      const reader = new FileReader();
      reader.onload = event => {
        // Generate a user-friendly identifier based on filename
        const fileNameWithoutExt = file.name.replace(/\.[^/.]+$/, '');
        const cleanName = fileNameWithoutExt
          .replace(/[^a-zA-Z0-9]/g, '_')
          .toLowerCase();
        const imageIndex = listPickerData.value.images.length + 1;

        const imageData = {
          identifier: `${cleanName}_${imageIndex}`,
          data: event.target.result.split(',')[1], // Remove data:image/...;base64, prefix
          preview: event.target.result, // Keep full data URL for preview
          description: file.name,
          originalName: file.name,
          size: file.size,
        };
        listPickerData.value.images.push(imageData);
      };
      reader.readAsDataURL(file);
    }
  };
  input.click();
};

// Format file size for display
const formatFileSize = bytes => {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / k ** i).toFixed(2)) + ' ' + sizes[i];
};

// Get image preview for Time Picker style selectors
const getImagePreview = identifier => {
  if (!identifier) return null;
  // Check inline images
  const inlineImage = listPickerData.value.images.find(
    img => img.identifier === identifier
  );
  if (inlineImage) return inlineImage.preview;

  // Check saved images
  const savedImage = savedImages.value.find(
    img => img.identifier === identifier
  );
  return savedImage?.image_url || null;
};

const removeImage = index => {
  listPickerData.value.images.splice(index, 1);
};

// Load saved images from ActiveStorage
const loadSavedImages = async () => {
  const inboxId = props.conversation?.inbox_id;
  if (!inboxId) {
    console.log('[AppleMessagesComposer] No inbox ID available');
    return;
  }

  console.log(
    '[AppleMessagesComposer] Loading saved images for inbox:',
    inboxId
  );
  loadingSavedImages.value = true;
  try {
    const response = await AppleMessagesImagesAPI.get({ inboxId });
    savedImages.value = response.data;
    console.log(
      '[AppleMessagesComposer] Loaded saved images:',
      savedImages.value.length,
      savedImages.value
    );
  } catch (error) {
    console.error(
      '[AppleMessagesComposer] Failed to load saved images:',
      error.response?.status,
      error.message
    );
  } finally {
    loadingSavedImages.value = false;
  }
};

// Use a saved image
const useSavedImage = savedImage => {
  // Check if image already exists in current list
  const existingIndex = listPickerData.value.images.findIndex(
    img => img.identifier === savedImage.identifier
  );

  if (existingIndex !== -1) {
    // Already in the list, just notify
    alert('This image is already added to the list picker');
    return;
  }

  // Fetch the base64 data and add to images
  fetch(savedImage.image_url)
    .then(response => response.blob())
    .then(blob => {
      const reader = new FileReader();
      reader.onload = event => {
        const imageData = {
          identifier: savedImage.identifier,
          data: event.target.result.split(',')[1], // Remove data URL prefix
          preview: event.target.result,
          description: savedImage.description || '',
          originalName: savedImage.original_name || savedImage.identifier,
          size: blob.size,
          fromStorage: true, // Mark as from storage
        };
        listPickerData.value.images.push(imageData);
      };
      reader.readAsDataURL(blob);
    })
    .catch(error => {
      console.error('Failed to load saved image:', error);
      alert('Failed to load the saved image');
    });
};

const addSection = () => {
  const newSection = {
    title: `Section ${listPickerData.value.sections.length + 1}`,
    multipleSelection: false,
    items: [{ title: 'Option 1', subtitle: 'Description 1' }],
  };
  listPickerData.value.sections.push(newSection);
};

const removeSection = sectionIndex => {
  if (listPickerData.value.sections.length > 1) {
    listPickerData.value.sections.splice(sectionIndex, 1);
  }
};

const addListItem = sectionIndex => {
  const newItem = {
    identifier: `item_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    title: 'New Item',
    subtitle: '',
  };
  listPickerData.value.sections[sectionIndex].items.push(newItem);
};

const removeListItem = (sectionIndex, itemIndex) => {
  listPickerData.value.sections[sectionIndex].items.splice(itemIndex, 1);
};

// Image picker state
const showImagePicker = ref(false);
const currentImageSelection = ref({ sectionIndex: null, itemIndex: null });
const imagePickerSource = ref('inline'); // 'inline' or 'shared'

const getImageByIdentifier = identifier => {
  return [...listPickerData.value.images, ...savedImages.value].find(
    img => img.identifier === identifier
  );
};

const openImagePicker = (sectionIndex, itemIndex) => {
  currentImageSelection.value = { sectionIndex, itemIndex };
  showImagePicker.value = true;
};

const selectImageForItem = image => {
  const { sectionIndex, itemIndex } = currentImageSelection.value;
  if (sectionIndex !== null && itemIndex !== null) {
    // If it's a saved image (from database), we need to add it to current session
    if (image.image_url && !image.preview) {
      // Check if this image is already in the current session
      const existsInSession = listPickerData.value.images.some(
        img => img.identifier === image.identifier
      );

      // If not in session, add it
      if (!existsInSession) {
        // Fetch the image data and add to session
        fetch(image.image_url)
          .then(response => response.blob())
          .then(blob => {
            const reader = new FileReader();
            reader.onload = e => {
              const imageData = {
                identifier: image.identifier,
                data: e.target.result.split(',')[1], // Remove data URL prefix
                preview: e.target.result,
                description: image.description || image.original_name,
                originalName: image.original_name,
                size: blob.size,
              };
              listPickerData.value.images.push(imageData);

              // Now assign to the item
              listPickerData.value.sections[sectionIndex].items[
                itemIndex
              ].image_identifier = image.identifier;
            };
            reader.readAsDataURL(blob);
          })
          .catch(err => {
            console.error('Failed to load saved image:', err);
            alert('Failed to load saved image');
          });
      } else {
        // Already in session, just assign
        listPickerData.value.sections[sectionIndex].items[
          itemIndex
        ].image_identifier = image.identifier;
      }
    } else {
      // It's a recently uploaded image, just assign
      listPickerData.value.sections[sectionIndex].items[
        itemIndex
      ].image_identifier = image.identifier;
    }
  }
  showImagePicker.value = false;
};

const closeImagePicker = () => {
  showImagePicker.value = false;
  currentImageSelection.value = { sectionIndex: null, itemIndex: null };
  imagePickerSource.value = 'inline'; // Reset to inline for next time
};

// Handle image selection from SharedImageSelector in modal
const handleModalSharedImageSelected = imageData => {
  if (imageData) {
    selectImageForItem(imageData);
  }
};

const addQuickReplyItem = () => {
  if (quickReplyData.value.items.length < 5) {
    quickReplyData.value.items.push({
      title: 'New Reply',
    });
  }
};

const removeQuickReplyItem = index => {
  if (quickReplyData.value.items.length > 2) {
    quickReplyData.value.items.splice(index, 1);
  }
};

const handleEnhancedTimePickerSave = timePickerData => {
  // Update the existing timePickerData with enhanced data
  Object.assign(timePickerData.value, timePickerData);
  showEnhancedTimePicker.value = false;

  // Debug logging
  console.log('🔥 AppleMessagesComposer - handleEnhancedTimePickerSave:', {
    timePickerData,
    timeslotsCount: timePickerData.event?.timeslots?.length,
    updatedTimePickerData: timePickerData.value,
  });

  // Don't auto-send, just save the configuration
};

const handleEnhancedTimePickerSaveAndSend = enhancedData => {
  // Update the existing timePickerData with enhanced data
  Object.assign(timePickerData.value, enhancedData);
  showEnhancedTimePicker.value = false;

  // Debug logging
  console.log(
    '🔥 AppleMessagesComposer - handleEnhancedTimePickerSaveAndSend:',
    {
      enhancedData,
      timeslotsCount: enhancedData.event?.timeslots?.length,
      updatedTimePickerData: timePickerData.value,
    }
  );

  // Automatically send the message
  sendAppleMessage();
};

const handleEnhancedTimePickerSaveAsTemplate = templateData => {
  showEnhancedTimePicker.value = false;
  emit('saveAsTemplate', templateData);
};

const handleEnhancedTimePickerPreview = enhancedData => {
  // Update the existing timePickerData for preview
  Object.assign(timePickerData.value, enhancedData);

  // Debug logging for preview
  console.log('🔥 AppleMessagesComposer - Preview Data:', {
    enhancedData,
    timeslotsCount: enhancedData.event?.timeslots?.length,
    updatedTimePickerData: timePickerData.value,
  });
};

const sendAppleMessage = () => {
  let content_type;
  let content_attributes;
  let content;

  switch (activeTab.value) {
    case 'list_picker':
      content_type = 'apple_list_picker';

      // Prepare content_attributes with images if they exist
      content_attributes = { ...listPickerData.value };

      // DEBUG: Log sections before conversion
      console.log(
        '[DEBUG] listPickerData.value.sections BEFORE conversion:',
        listPickerData.value.sections
      );

      // Transform sections to use snake_case for backend
      content_attributes.sections = listPickerData.value.sections.map(
        section => {
          console.log('[DEBUG] Processing section:', {
            title: section.title,
            multipleSelection_value: section.multipleSelection,
            multipleSelection_type: typeof section.multipleSelection,
            section_keys: Object.keys(section),
          });

          const result = {
            title: section.title,
            multiple_selection: section.multipleSelection ?? false, // Use nullish coalescing
            items: section.items.map(item => ({
              title: item.title,
              subtitle: item.subtitle,
              image_identifier: item.image_identifier,
            })),
          };

          // Determine the reason for multiple_selection value
          let multipleSelectionReason = 'other';
          if (section.multipleSelection === undefined) {
            multipleSelectionReason = 'undefined->false';
          } else if (section.multipleSelection === null) {
            multipleSelectionReason = 'null->false';
          } else if (section.multipleSelection === false) {
            multipleSelectionReason = 'explicitly false';
          } else if (section.multipleSelection === true) {
            multipleSelectionReason = 'explicitly true';
          }

          console.log('[DEBUG] Converted section:', {
            title: result.title,
            multiple_selection: result.multiple_selection,
            reason: multipleSelectionReason,
          });

          return result;
        }
      );

      // DEBUG: Log sections after conversion
      console.log(
        '[DEBUG] content_attributes.sections AFTER conversion:',
        content_attributes.sections
      );

      // Debug: log items with image_identifier
      console.log(
        '[AMB ListPicker] Items with images:',
        content_attributes.sections
          .flatMap(s => s.items)
          .filter(i => i.image_identifier)
          .map(i => ({ title: i.title, image_identifier: i.image_identifier }))
      );

      // Only include images if they exist and are not empty
      if (
        listPickerData.value.images &&
        listPickerData.value.images.length > 0
      ) {
        content_attributes.images = listPickerData.value.images.map(img => ({
          identifier: img.identifier, // Use the original identifier
          data: img.data,
          description: img.description || img.originalName || img.identifier,
          originalName: img.originalName || img.identifier,
        }));
        console.log(
          '[AMB ListPicker] Sending images:',
          content_attributes.images.length,
          content_attributes.images.map(i => i.identifier)
        );
      } else {
        console.log('[AMB ListPicker] No images to send');
      }

      content = listPickerData.value.received_title || 'List Picker Message';
      break;
    case 'quick_reply':
      content_type = 'apple_quick_reply';

      // Clean items array - ensure no undefined values
      const cleanItems = (quickReplyData.value?.items || [])
        .map(item => {
          const cleanItem = {
            title: item?.title || 'Option',
            value: item?.value || item?.title || 'Option',
          };
          // Only add identifier if it exists and is not undefined
          if (item?.identifier && item.identifier !== undefined) {
            cleanItem.identifier = item.identifier;
          }
          return cleanItem;
        })
        .filter(item => item.title && item.title !== undefined); // Remove any items without valid title

      // Build content_attributes ensuring NO undefined values
      // Only add fields that have actual values (not undefined)
      const summaryText = quickReplyData.value?.summary_text;

      content_attributes = {
        summary_text: summaryText || 'Quick Reply Question',
        items: cleanItems,
        received_title: 'Please select an option',
        received_subtitle: '',
        received_style: 'small',
        reply_title: 'Selected: ${item.title}',
        reply_subtitle: '',
        reply_style: 'icon',
      };

      // Remove any undefined values from content_attributes
      content_attributes = Object.fromEntries(
        Object.entries(content_attributes).filter(([_, value]) => value !== undefined)
      );

      content = summaryText || 'Quick Reply Message';
      break;
    case 'time_picker': {
      content_type = 'apple_time_picker';

      // Debug: Log current state before sending
      console.log('[AMB TimePicker] sendAppleMessage - Current state:', {
        globalSelectedSlotsSize: globalSelectedSlots.value.size,
        timePickerDataEventTimeslots: timePickerData.value.event.timeslots,
        timeslotsLength: timePickerData.value.event.timeslots?.length || 0,
        // Check if slots have startTime
        firstSlot: timePickerData.value.event.timeslots?.[0],
        firstSlotHasStartTime:
          timePickerData.value.event.timeslots?.[0]?.startTime !== undefined,
        firstSlotHasStartTimeSnake:
          timePickerData.value.event.timeslots?.[0]?.start_time !== undefined,
      });

      // Validate that slots are selected
      if (
        !timePickerData.value.event.timeslots ||
        timePickerData.value.event.timeslots.length === 0
      ) {
        alert(
          'Please select at least one time slot before sending. Click on the time slots in the calendar to select them.'
        );
        return;
      }

      // Transform timeslots to snake_case (similar to list picker transformation)
      const transformedTimeslots = timePickerData.value.event.timeslots.map(
        slot => {
          const startTime = slot.startTime || slot.start_time;

          // Log warning if startTime is missing
          if (!startTime) {
            console.warn('[AMB TimePicker] Slot missing startTime:', slot);
          }

          return {
            identifier: slot.identifier,
            start_time: startTime,
            duration: slot.duration,
          };
        }
      );

      console.log('[AMB TimePicker] Transformation result:', {
        originalSlots: timePickerData.value.event.timeslots,
        transformedSlots: transformedTimeslots,
        firstOriginal: timePickerData.value.event.timeslots?.[0],
        firstTransformed: transformedTimeslots?.[0],
      });

      // Map camelCase to snake_case for backend
      content_attributes = {
        event: {
          ...timePickerData.value.event,
          timeslots: transformedTimeslots, // Use transformed timeslots
        },
        timezone_offset: timePickerData.value.timezone_offset,
        received_title: timePickerData.value.received_title,
        received_subtitle: timePickerData.value.received_subtitle,
        received_image_identifier: timePickerData.value.receivedImageIdentifier, // Map camelCase to snake_case
        received_style: timePickerData.value.received_style,
        reply_title: timePickerData.value.reply_title,
        reply_subtitle: timePickerData.value.reply_subtitle,
        reply_image_identifier: timePickerData.value.replyImageIdentifier, // Map camelCase to snake_case
        reply_style: timePickerData.value.reply_style,
        reply_image_title: timePickerData.value.reply_image_title,
        reply_image_subtitle: timePickerData.value.reply_image_subtitle,
        reply_secondary_subtitle: timePickerData.value.reply_secondary_subtitle,
        reply_tertiary_subtitle: timePickerData.value.reply_tertiary_subtitle,
      };

      // Include images if they exist (same as list picker)
      if (
        timePickerData.value.images &&
        timePickerData.value.images.length > 0
      ) {
        content_attributes.images = timePickerData.value.images.map(img => ({
          identifier: img.identifier,
          data: img.data,
          description: img.description || img.originalName || img.identifier,
          originalName: img.originalName || img.identifier,
        }));
        console.log(
          '[AMB TimePicker] Sending images:',
          content_attributes.images.length,
          content_attributes.images.map(i => i.identifier)
        );
      } else {
        console.log('[AMB TimePicker] No images to send');
      }

      console.log('[AMB TimePicker] Using image identifiers:', {
        received: content_attributes.received_image_identifier,
        reply: content_attributes.reply_image_identifier,
      });

      content = timePickerData.value.event?.title || 'Time Picker Message';
      break;
    }
    case 'forms':
      // Forms are created through the modal, this shouldn't be reached
      return;
    case 'imessage_apps':
      if (!selectedApp.value) {
        return;
      }
      content_type = 'apple_custom_app';

      // Only send fields that are allowed by the backend validator
      // ALLOWED_APPLE_CUSTOM_APP_KEYS = [:app_id, :app_name, :bid, :url, :use_live_layout]
      content_attributes = {
        app_id: selectedApp.value.appId || selectedApp.value.app_id,
        app_name: selectedApp.value.name,
        bid: selectedApp.value.bid,
        url: selectedApp.value.url,
        use_live_layout:
          selectedApp.value.useLiveLayout ||
          selectedApp.value.use_live_layout ||
          false,
      };

      content = `${selectedApp.value.name}: ${selectedApp.value.description || 'App invocation'}`;

      // Debug logging for 422 error
      console.log('🔧 Debug - Selected app data:', selectedApp.value);
      console.log(
        '🔧 Debug - Content attributes being sent (filtered):',
        content_attributes
      );
      break;
  }

  console.log('[DEBUG AppleMessagesComposer] About to emit - full payload:', {
    content_type,
    sections: content_attributes.sections ? JSON.parse(JSON.stringify(content_attributes.sections)) : 'N/A',
    content_attributes_full: JSON.parse(JSON.stringify(content_attributes)),
  });
  if (content_attributes.sections) {
    console.log(
      '[DEBUG AppleMessagesComposer] CRITICAL - multiple_selection values:',
      content_attributes.sections
        .map((s, i) => `Section ${i}: ${s.multiple_selection}`)
        .join(', ')
    );
  }

  emit('send', {
    content_type,
    content_attributes,
    content,
  });
};

const cancelComposer = () => {
  emit('cancel');
};

const saveAsTemplate = () => {
  let messageType;
  let messageData;

  switch (activeTab.value) {
    case 'list_picker':
      messageType = 'list_picker';
      messageData = { ...listPickerData.value };
      break;
    case 'quick_reply':
      messageType = 'quick_reply';
      messageData = { ...quickReplyData.value };
      break;
    case 'time_picker':
      // CRITICAL: Sync selected slots from inline picker to timePickerData BEFORE saving
      updateTimePickerData();
      messageType = 'time_picker';
      messageData = { ...timePickerData.value };

      console.log('[AMB Templates] Saving template with timeslots:', {
        selectedSlotsCount: globalSelectedSlots.value.size,
        timeslotsInData: messageData.event?.timeslots?.length || 0,
        timeslots: messageData.event?.timeslots,
      });
      break;
    default:
      return;
  }

  // Store the data and show the modal
  pendingTemplateData.value = {
    messageType,
    messageData,
  };
  showSaveAsTemplateModal.value = true;
};

// Handle save from modal
const handleTemplateSave = () => {
  showSaveAsTemplateModal.value = false;
  showFormBuilder.value = false;
  pendingTemplateData.value = null;
};

// Handle save and send from modal
const handleTemplateSaveAndSend = () => {
  showSaveAsTemplateModal.value = false;
  showFormBuilder.value = false;
  // Send the message immediately after saving
  sendAppleMessage();
  pendingTemplateData.value = null;
};

// Handle modal close
const closeTemplateModal = () => {
  showSaveAsTemplateModal.value = false;
  // Don't close form builder when user cancels - let them continue editing
  pendingTemplateData.value = null;
};

// Form Builder Handlers
const openFormBuilder = () => {
  showFormBuilder.value = true;
};

const handleFormCreated = formData => {
  console.log('[AMB Form] Form created with data:', formData);

  // Emit both events to ensure proper handling
  emit('send', formData);
  emit('sendAppleMessage', formData);

  showFormBuilder.value = false;
};

const handleFormSaveAsTemplate = templateData => {
  // Store the template data and show the Save As Template modal
  pendingTemplateData.value = templateData;
  showSaveAsTemplateModal.value = true;
  // Keep the form builder open in the background
};

const closeFormBuilder = () => {
  showFormBuilder.value = false;
};

// iMessage App Handlers
const selectApp = appId => {
  selectedAppId.value = appId;
  selectedAppData.value = {};
};

const updateAppData = (key, value) => {
  selectedAppData.value[key] = value;
};

// Handle image upload from EnhancedTimePickerModal
const handleImageUpload = imageInfo => {
  // Generate identifier
  const fileNameWithoutExt = imageInfo.name.replace(/\.[^/.]+$/, '');
  const cleanName = fileNameWithoutExt
    .replace(/[^a-zA-Z0-9]/g, '_')
    .toLowerCase();
  const imageIndex = listPickerData.value.images.length + 1;

  const imageData = {
    identifier: `${cleanName}_${imageIndex}`,
    data: imageInfo.data.split(',')[1], // Remove data:image/...;base64, prefix
    preview: imageInfo.data, // Keep full data URL for preview
    description: imageInfo.name,
    originalName: imageInfo.name,
    size: imageInfo.size,
  };

  // Add to list picker images (for shared image library)
  listPickerData.value.images.push(imageData);

  // Also add to time picker images so it's included when saving
  if (!timePickerData.value.images) {
    timePickerData.value.images = [];
  }
  timePickerData.value.images.push(imageData);
};

// Handle image upload from AppleFormBuilder
const handleFormImageUpload = async imageData => {
  try {
    const inboxId = props.conversation?.inbox_id;
    if (!inboxId) {
      console.error('No inbox ID available');
      alert('Unable to save image: No inbox found');
      return;
    }

    // Save image to backend using the API
    // Note: The controller expects image_data as a direct parameter, not nested
    const response = await AppleMessagesImagesAPI.create({
      inboxId,
      identifier: imageData.identifier,
      image_data: imageData.data, // Changed from imageData to image_data
      description: imageData.description || imageData.originalName,
      original_name: imageData.originalName,
      filename: imageData.originalName,
    });

    // Add to saved images list so it appears in the selector
    if (response && response.data) {
      const newImage = response.data;
      savedImages.value.push({
        identifier: newImage.identifier,
        description: newImage.description,
        image_url: newImage.image_url,
        original_name: newImage.original_name,
        preview: imageData.preview, // Use the preview from upload
      });

      console.log(
        '[AppleFormBuilder] Image saved successfully:',
        newImage.identifier
      );
    }
  } catch (error) {
    console.error('Failed to save image:', error);
    alert('Failed to save image. Please try again.');
  }
};

// Select image for time picker (automatically sets both received and reply)
const selectTimePickerImage = identifier => {
  console.log('[AMB TimePicker] Image selected:', identifier);
  timePickerData.value.receivedImageIdentifier = identifier;
  timePickerData.value.replyImageIdentifier = identifier;
  console.log('[AMB TimePicker] Updated identifiers:', {
    received: timePickerData.value.receivedImageIdentifier,
    reply: timePickerData.value.replyImageIdentifier,
  });
};

// SharedImageSelector event handlers
const handleListPickerHeaderImageSelected = imageData => {
  if (imageData) {
    console.log('[AMB ListPicker] Shared header image selected:', imageData);
    listPickerData.value.received_image_identifier = imageData.identifier;
  } else {
    console.log('[AMB ListPicker] Header image cleared');
    listPickerData.value.received_image_identifier = '';
  }
};

const handleTimePickerSharedImageSelected = imageData => {
  if (imageData) {
    console.log('[AMB TimePicker] Shared image selected:', imageData);
    timePickerData.value.receivedImageIdentifier = imageData.identifier;
    timePickerData.value.replyImageIdentifier = imageData.identifier;
  } else {
    console.log('[AMB TimePicker] Shared image cleared');
    timePickerData.value.receivedImageIdentifier = '';
    timePickerData.value.replyImageIdentifier = '';
  }
};

// Template handling
const toggleTemplateSelector = () => {
  showTemplateSelector.value = !showTemplateSelector.value;
};

const handleTemplateSelect = async item => {
  console.log('[AMB Templates] ===== handleTemplateSelect CALLED =====');
  console.log('[AMB Templates] Template selected:', item);

  if (item.type === 'canned') {
    // Handle canned response - not applicable for Apple Messages
    console.log('[AMB Templates] Canned response, closing selector');
    showTemplateSelector.value = false;
    return;
  }

  if (item.type === 'template') {
    const template = item.template;
    console.log('[AMB Templates] Processing template:', template);

    try {
      // Call the render API to get the formatted message
      const inboxChannelType =
        props.conversation?.inbox?.channel_type ||
        'Channel::AppleMessagesForBusiness';
      console.log('[AMB Templates] Channel type:', inboxChannelType);

      // Generate sample parameters for time picker templates
      let parameters = {};
      if (
        template.category === 'scheduling' ||
        template.name.includes('time_picker')
      ) {
        // Generate 3 sample time slots starting from tomorrow at 9 AM
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(9, 0, 0, 0);

        parameters.available_slots = [
          new Date(tomorrow.getTime()).toISOString(),
          new Date(tomorrow.getTime() + 2 * 60 * 60 * 1000).toISOString(), // +2 hours
          new Date(tomorrow.getTime() + 4 * 60 * 60 * 1000).toISOString(), // +4 hours
        ];
      }

      const response = await store.dispatch('messageTemplates/render', {
        templateId: template.id,
        parameters: parameters,
        channelType: inboxChannelType,
      });

      console.log('[AMB Templates] Rendered template response:', response);

      // Extract data from response
      const renderedData = response.data || response;

      // Send the rendered message
      if (
        renderedData &&
        renderedData.content_type &&
        renderedData.content_attributes
      ) {
        const messageData = {
          content_type: renderedData.content_type,
          content_attributes: renderedData.content_attributes,
          content: renderedData.content,
          // Include template_id so backend can attach template files
          template_id: template.id,
        };

        console.log(
          '[AMB Templates] Emitting sendAppleMessage event with:',
          messageData
        );
        console.log(
          '[AMB Templates] Template has',
          renderedData.attachments?.length || 0,
          'attachments'
        );

        emit('send', messageData);
        emit('sendAppleMessage', messageData);
      } else {
        console.error('[AMB Templates] Invalid response format:', renderedData);
        alert('Error: Invalid template response format');
      }
    } catch (error) {
      console.error('[AMB Templates] Error rendering template:', error);
      const errorMessage =
        error.response?.data?.details || error.message || 'Unknown error';
      alert(`Error loading template: ${errorMessage}`);
    }
  }

  showTemplateSelector.value = false;
};

// Register global handler immediately after definition
window.handleAppleTemplateSelect = handleTemplateSelect;
console.log(
  '[AMB Templates] Registered global template handler:',
  typeof handleTemplateSelect
);

// Watch for template selection from store (fallback for event propagation issues)
const selectedTemplateFromStore = computed(() => {
  const value = store.getters['messageTemplates/getSelectedTemplate'];
  console.log(
    '[AMB Templates] Computed selectedTemplateFromStore evaluated:',
    value
  );
  return value;
});

console.log('[AMB Templates] Setting up watcher for selectedTemplateFromStore');

watch(
  selectedTemplateFromStore,
  async (newValue, oldValue) => {
    console.log(
      '[AMB Templates] Watcher triggered! Old:',
      oldValue,
      'New:',
      newValue
    );
    if (newValue && newValue.type === 'template') {
      console.log(
        '[AMB Templates] Store watcher detected template selection:',
        newValue
      );
      await handleTemplateSelect(newValue);
      // Clear the selection after handling
      store.commit('messageTemplates/SET_SELECTED_TEMPLATE', null);
    }
  },
  { deep: true, immediate: true }
);

const loadTemplateIntoComposer = template => {
  console.log('[AMB Templates] Loading template:', template.name);

  // Determine message type from content blocks
  const contentBlocks = template.contentBlocks || template.content_blocks || [];

  if (contentBlocks.length === 0) {
    console.warn('[AMB Templates] No content blocks in template');
    return;
  }

  // Find the primary content block type
  const primaryBlock = contentBlocks[0];
  const blockType = primaryBlock.blockType || primaryBlock.block_type;

  console.log('[AMB Templates] Primary block type:', blockType);

  switch (blockType) {
    case 'quick_reply':
      loadQuickReplyTemplate(primaryBlock);
      activeTab.value = 'quick_reply';
      break;
    case 'list_picker':
      loadListPickerTemplate(primaryBlock);
      activeTab.value = 'list_picker';
      break;
    case 'time_picker':
      loadTimePickerTemplate(primaryBlock);
      activeTab.value = 'time_picker';
      break;
    case 'form':
      // Forms need to go through the form builder
      console.log(
        '[AMB Templates] Form templates not yet supported via selector'
      );
      break;
    default:
      console.warn('[AMB Templates] Unknown block type:', blockType);
  }
};

const loadQuickReplyTemplate = block => {
  const config = block.blockConfig || block.block_config || {};

  quickReplyData.value = {
    summary_text:
      config.summaryText || config.summary_text || 'Quick Reply Question',
    items: (config.items || []).map(item => ({
      title: item.title || item.label || 'Reply',
    })),
  };

  console.log('[AMB Templates] Loaded quick reply:', quickReplyData.value);
};

const loadListPickerTemplate = block => {
  const config = block.blockConfig || block.block_config || {};

  // Load sections
  const sections = config.sections || [];
  listPickerData.value.sections = sections.map(section => ({
    title: section.title || 'Section',
    multipleSelection:
      section.multipleSelection || section.multiple_selection || false,
    items: (section.items || []).map(item => ({
      identifier:
        item.identifier ||
        `item_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      title: item.title || '',
      subtitle: item.subtitle || '',
      image_identifier: item.imageIdentifier || item.image_identifier || '',
    })),
  }));

  // Load images if present
  if (config.images && Array.isArray(config.images)) {
    listPickerData.value.images = config.images.map(img => ({
      identifier: img.identifier,
      data: img.data,
      preview: img.data ? `data:image/jpeg;base64,${img.data}` : img.preview,
      description: img.description || img.identifier,
      originalName: img.originalName || img.original_name || img.identifier,
      size: img.size || 0,
    }));
  }

  // Load received message config - backend always returns snake_case via TemplateFacade
  listPickerData.value.received_title =
    config.received_title || 'Please select an option';
  listPickerData.value.received_subtitle = config.received_subtitle || '';
  listPickerData.value.received_image_identifier =
    config.received_image_identifier || '';
  listPickerData.value.received_style = config.received_style || 'icon';

  // Load reply message config
  listPickerData.value.reply_title = config.reply_title || 'Selection Made';
  listPickerData.value.reply_subtitle = config.reply_subtitle || '';
  listPickerData.value.reply_style = config.reply_style || 'icon';
  listPickerData.value.reply_image_title = config.reply_image_title || '';
  listPickerData.value.reply_image_subtitle = config.reply_image_subtitle || '';
  listPickerData.value.reply_secondary_subtitle =
    config.reply_secondary_subtitle || '';
  listPickerData.value.reply_tertiary_subtitle =
    config.reply_tertiary_subtitle || '';

  console.log('[AMB Templates] Loaded list picker:', listPickerData.value);
};

const loadTimePickerTemplate = block => {
  const config = block.blockConfig || block.block_config || {};

  // Load event details - backend always returns snake_case via TemplateFacade
  timePickerData.value.event = {
    title: config.event_title || config.event?.title || 'Schedule Appointment',
    description:
      config.event_description ||
      config.event?.description ||
      'Select a time slot',
    timeslots: config.timeslots || config.event?.timeslots || [],
  };

  // Load timezone - backend always returns snake_case via TemplateFacade
  timePickerData.value.timezone_offset = config.timezone_offset || -480;

  // Load received message config
  timePickerData.value.received_title =
    config.received_title || 'Please pick a time';
  timePickerData.value.received_subtitle =
    config.received_subtitle || 'Select your preferred time slot';
  timePickerData.value.receivedImageIdentifier =
    config.received_image_identifier || '';
  timePickerData.value.received_style = config.received_style || 'icon';

  // Load reply message config
  timePickerData.value.reply_title = config.reply_title || 'Thank you!';
  timePickerData.value.reply_subtitle = config.reply_subtitle || '';
  timePickerData.value.replyImageIdentifier =
    config.reply_image_identifier || '';
  timePickerData.value.reply_style = config.reply_style || 'icon';
  timePickerData.value.reply_image_title = config.reply_image_title || '';
  timePickerData.value.reply_image_subtitle = config.reply_image_subtitle || '';
  timePickerData.value.reply_secondary_subtitle =
    config.reply_secondary_subtitle || '';
  timePickerData.value.reply_tertiary_subtitle =
    config.reply_tertiary_subtitle || '';

  // Load images if present
  if (config.images && Array.isArray(config.images)) {
    timePickerData.value.images = config.images.map(img => ({
      identifier: img.identifier,
      data: img.data,
      preview: img.data ? `data:image/jpeg;base64,${img.data}` : img.preview,
      description: img.description || img.identifier,
      originalName: img.originalName || img.original_name || img.identifier,
      size: img.size || 0,
    }));
  }

  console.log('[AMB Templates] Loaded time picker:', timePickerData.value);
};

// Payment template loading
const loadPaymentTemplate = templateType => {
  console.log('[AMB Payment] Loading payment template:', templateType);

  const templates = {
    simple: {
      merchantName: 'Demo Store',
      currencyCode: 'USD',
      countryCode: 'US',
      lineItems: [{ label: 'Product A', amount: '10.00', type: 'final' }],
      total: { label: 'Total', amount: '10.00', type: 'final' },
      requiresShipping: false,
      requiresBilling: true,
    },
    shipping: {
      merchantName: 'Demo Store',
      currencyCode: 'USD',
      countryCode: 'US',
      lineItems: [
        { label: 'Wireless Headphones', amount: '99.99', type: 'final' },
        { label: 'Tax', amount: '8.00', type: 'final' },
        { label: 'Shipping', amount: '5.00', type: 'final' },
      ],
      total: { label: 'Total', amount: '112.99', type: 'final' },
      requiresShipping: true,
      requiresBilling: true,
    },
    service: {
      merchantName: 'Spa Services',
      currencyCode: 'USD',
      countryCode: 'US',
      lineItems: [
        { label: 'Massage Therapy (60 min)', amount: '80.00', type: 'final' },
        { label: 'Service Fee', amount: '10.00', type: 'final' },
      ],
      total: { label: 'Total', amount: '90.00', type: 'final' },
      requiresShipping: false,
      requiresBilling: true,
    },
    euro: {
      merchantName: 'European Shop',
      currencyCode: 'EUR',
      countryCode: 'DE',
      lineItems: [
        { label: 'Premium Product', amount: '149.99', type: 'final' },
      ],
      total: { label: 'Total', amount: '149.99', type: 'final' },
      requiresShipping: false,
      requiresBilling: true,
    },
  };

  const template = templates[templateType];
  if (!template) {
    console.error('[AMB Payment] Unknown template type:', templateType);
    return;
  }

  // Send the payment message immediately
  const messageData = {
    content_type: 'apple_pay',
    content_attributes: template,
    content: `${template.merchantName} - ${template.total.label}: ${template.currencyCode} ${template.total.amount}`,
  };

  console.log('[AMB Payment] Sending payment template:', messageData);
  emit('send', messageData);
};

// Custom Payload Methods
const validateCustomPayload = () => {
  if (isValidJson.value) {
    alert('✅ Payload is valid JSON');
  } else {
    alert(`❌ Invalid JSON: ${jsonValidationError.value}`);
  }
};

const getErrorTitle = errorType => {
  const titles = {
    validation: 'JSON Validation Error',
    send_error: 'Failed to Send Message',
    apple_error: 'Apple MSP Gateway Error',
    payload_too_large: 'Payload Size Limit Exceeded',
    rate_limit: 'Rate Limit Exceeded',
    permission_error: 'Permission Denied',
    network_error: 'Network Error',
    warning: 'Warning',
  };
  return titles[errorType] || 'Error';
};

const getSuggestionsForError = error => {
  const suggestions = {
    validation: [
      'Check your JSON syntax for missing commas, brackets, or quotes',
      'Use a JSON validator tool to identify the exact issue',
      'Enable "Allow experimental payloads" to bypass validation (not recommended)',
    ],
    apple_error: [
      'Verify your payload matches Apple MSP Gateway requirements',
      'Check that all required fields are present and correctly formatted',
      "Review Apple Business Chat documentation for the message type you're sending",
      'Try sending a simpler payload to isolate the issue',
    ],
    send_error: [
      'Verify the conversation is active and the contact is reachable',
      'Check your network connection',
      'Try again in a few moments',
      'Contact support if the issue persists',
    ],
    payload_too_large: [
      'Reduce the size of your payload (current limit: 10MB)',
      'Compress or optimize any embedded data',
      'Consider splitting into multiple messages',
    ],
    rate_limit: [
      'Wait a few minutes before sending more custom payloads',
      'Current limit: 100 payloads per hour per account',
    ],
  };
  return suggestions[error.type] || [];
};

const enhanceError = error => {
  error.suggestions = getSuggestionsForError(error);
  return error;
};

const sendCustomPayload = async () => {
  // Clear previous errors
  sendError.value = null;

  // Validate JSON if validation is enabled
  if (!isValidJson.value && !customPayloadData.value.skipValidation) {
    sendError.value = enhanceError({
      type: 'validation',
      message: 'Please fix JSON errors before sending',
      details: jsonValidationError.value,
    });
    return;
  }

  const messageData = {
    content_type: 'apple_custom_payload',
    content_attributes: {
      custom_payload: customPayloadData.value.payload,
      skip_validation: customPayloadData.value.skipValidation,
      apply_case_transform: customPayloadData.value.applyCaseTransform,
    },
    content: 'Custom Apple Messages payload',
  };

  try {
    isSending.value = true;
    console.log('[Custom Payload] Sending:', messageData);

    emit('send', messageData);

    // Success - reset form
    customPayloadData.value = {
      payload: '',
      skipValidation: false,
      applyCaseTransform: false,
    };
  } catch (error) {
    // Handle sending errors
    console.error('[Custom Payload] Send error:', error);

    if (error.response) {
      // Server returned an error response
      const errorData = error.response.data;

      sendError.value = enhanceError({
        type: errorData.error_type || 'send_error',
        message: errorData.message || 'Failed to send custom payload',
        details: errorData.details || null,
        appleError: errorData.apple_error || null,
      });
    } else if (error.request) {
      // Request was made but no response received
      sendError.value = enhanceError({
        type: 'network_error',
        message: 'No response from server. Please check your connection.',
        details: 'Network timeout or server unreachable',
      });
    } else {
      // Something else went wrong
      sendError.value = enhanceError({
        type: 'send_error',
        message: error.message || 'An unexpected error occurred',
        details: error.toString(),
      });
    }

    console.error('[Custom Payload] Enhanced error:', sendError.value);
  } finally {
    isSending.value = false;
  }
};

// Clear send error when user modifies payload
watch(
  () => customPayloadData.value.payload,
  () => {
    if (sendError.value) {
      sendError.value = null;
    }
  }
);
</script>

<!-- eslint-disable vue/no-bare-strings-in-template -->
<!-- eslint-disable @intlify/vue-i18n/no-raw-text -->
<!-- eslint-disable vue/no-static-inline-styles -->
<template>
  <div class="apple-messages-composer bg-n-solid-1 text-n-slate-12">
    <!-- Header with Tabs and Template Button -->
    <div class="flex items-center justify-between mb-4 border-b border-n-weak">
      <!-- Tabs -->
      <div class="flex flex-wrap space-x-1 gap-y-1">
        <button
          v-for="tab in [
            { id: 'quick_reply', emoji: '💬', label: 'Quick Reply' },
            { id: 'list_picker', emoji: '📋', label: 'List Picker' },
            { id: 'time_picker', emoji: '🕐', label: 'Time Picker' },
            { id: 'forms', emoji: '📝', label: 'Forms' },
            { id: 'imessage_apps', emoji: '📱', label: 'iMessage Apps' },
            { id: 'oauth', emoji: '🔐', label: 'OAuth' },
            { id: 'apple_pay', emoji: '💳', label: 'Apple Pay' },
            { id: 'custom_payload', emoji: '🔧', label: 'Custom Payload' },
          ]"
          :key="tab.id"
          class="px-3 py-2 text-xl border-b-2 transition-colors"
          :class="
            activeTab === tab.id
              ? 'border-n-blue-8 text-n-blue-11 dark:text-n-blue-10'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
          "
          :title="tab.label"
          @click="activeTab = tab.id"
        >
          {{ tab.emoji }}
        </button>
      </div>
    </div>

    <!-- List Picker Tab -->
    <div v-if="activeTab === 'list_picker'" class="space-y-6">
      <!-- Received Message Configuration -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
        >
          Received Message
        </h4>

        <!-- Title, Subtitle, Style in Grid -->
        <div class="grid grid-cols-2 gap-3 mb-4">
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Title</label
            >
            <input
              v-model="listPickerData.received_title"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Please select an option"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Subtitle</label
            >
            <input
              v-model="listPickerData.received_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Optional subtitle"
            />
          </div>
          <div class="col-span-2">
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Style</label
            >
            <select
              v-model="listPickerData.received_style"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
            >
              <option
                v-for="style in styleOptions"
                :key="style.value"
                :value="style.value"
              >
                {{ style.label }}
              </option>
            </select>
          </div>
        </div>

        <!-- Header Image Section (Full Width) -->
        <div>
          <label
            class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
          >
            Header Image
          </label>

          <!-- Toggle: Inline vs Shared -->
          <div
            class="flex items-center gap-2 mb-3 p-2 bg-n-alpha-1 dark:bg-n-alpha-2 rounded-lg"
          >
            <button
              type="button"
              class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
              :class="
                listPickerHeaderImageSource === 'inline'
                  ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                  : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
              "
              @click="listPickerHeaderImageSource = 'inline'"
            >
              Inline Images
            </button>
            <button
              type="button"
              class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
              :class="
                listPickerHeaderImageSource === 'shared'
                  ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                  : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
              "
              @click="listPickerHeaderImageSource = 'shared'"
            >
              Shared Images
            </button>
          </div>

          <!-- Inline Image Grid -->
          <div
            v-if="listPickerHeaderImageSource === 'inline'"
            class="grid grid-cols-4 gap-2"
          >
            <div
              class="relative cursor-pointer border-2 rounded-lg overflow-hidden transition-all"
              :class="
                listPickerData.received_image_identifier === ''
                  ? 'border-n-blue-8 dark:border-n-blue-9 bg-n-blue-1 dark:bg-n-blue-2'
                  : 'border-n-weak dark:border-n-slate-6 hover:border-n-blue-8 dark:hover:border-n-blue-9'
              "
              @click="listPickerData.received_image_identifier = ''"
            >
              <div
                class="h-16 flex items-center justify-center bg-n-alpha-2 dark:bg-n-alpha-3"
              >
                <span class="text-2xl">🚫</span>
              </div>
              <div
                class="text-xs text-center py-1 bg-n-solid-1 dark:bg-n-alpha-2"
              >
                None
              </div>
            </div>
            <div
              v-for="image in [...listPickerData.images, ...savedImages]"
              :key="image.identifier"
              class="relative cursor-pointer border-2 rounded-lg overflow-hidden transition-all"
              :class="
                listPickerData.received_image_identifier === image.identifier
                  ? 'border-n-blue-8 dark:border-n-blue-9 bg-n-blue-1 dark:bg-n-blue-2'
                  : 'border-n-weak dark:border-n-slate-6 hover:border-n-blue-8 dark:hover:border-n-blue-9'
              "
              @click="
                listPickerData.received_image_identifier = image.identifier
              "
            >
              <img
                :src="image.preview || image.image_url"
                :alt="image.originalName || image.description"
                class="w-full h-16 object-cover"
              />
              <div
                class="text-xs text-center py-1 bg-n-solid-1 dark:bg-n-alpha-2 truncate px-1"
                :title="
                  image.originalName ||
                  image.original_name ||
                  image.description ||
                  image.identifier
                "
              >
                {{
                  (
                    image.originalName ||
                    image.original_name ||
                    image.description ||
                    image.identifier
                  ).substring(0, 12)
                }}...
              </div>
              <div
                v-if="
                  listPickerData.received_image_identifier === image.identifier
                "
                class="absolute top-1 right-1 bg-n-blue-9 dark:bg-n-blue-10 rounded-full w-5 h-5 flex items-center justify-center"
              >
                <span class="text-white text-xs">✓</span>
              </div>
            </div>
          </div>

          <!-- Shared Image Selector (Full Width) -->
          <div v-else-if="listPickerHeaderImageSource === 'shared'">
            <SharedImageSelector
              v-model="listPickerData.received_image_identifier"
              :account-id="store.getters.getCurrentAccountId"
              image-type="system"
              @image-selected="handleListPickerHeaderImageSelected"
            />
          </div>
        </div>
      </div>

      <!-- Images Management -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <div class="flex justify-between items-center mb-3">
          <h4
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Item Images
          </h4>
          <button
            class="px-3 py-1 bg-n-blue-9 dark:bg-n-blue-10 text-white dark:text-n-slate-12 rounded text-sm hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors"
            @click="addImage"
          >
            Add Image
          </button>
        </div>

        <div
          v-if="listPickerData.images.length === 0"
          class="text-sm text-n-slate-11 dark:text-n-slate-10 italic"
        >
          No images added. Images can be referenced by list items.
        </div>
        <div v-else class="grid grid-cols-3 gap-2">
          <div
            v-for="(image, index) in listPickerData.images"
            :key="index"
            class="relative group border border-n-weak dark:border-n-slate-6 rounded-lg overflow-hidden hover:border-n-blue-8 dark:hover:border-n-blue-9 transition-colors"
          >
            <img
              v-if="image.preview"
              :src="image.preview"
              :alt="image.originalName || image.description"
              class="w-full h-24 object-cover"
            />
            <div
              v-else
              class="w-full h-24 bg-n-alpha-3 dark:bg-n-alpha-4 flex items-center justify-center"
            >
              <span class="text-2xl">📷</span>
            </div>
            <div
              class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-70 transition-opacity flex items-center justify-center"
            >
              <button
                class="opacity-0 group-hover:opacity-100 px-2 py-1 bg-n-ruby-9 text-white rounded text-xs hover:bg-n-ruby-10 transition-all"
                @click.stop="removeImage(index)"
              >
                Remove
              </button>
            </div>
            <div
              class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-75 text-white text-xs px-2 py-1 truncate"
              :title="`${image.originalName || image.description} (${formatFileSize(image.size)})`"
            >
              {{ image.originalName || image.description }}
            </div>
            <div
              class="absolute top-1 right-1 bg-black bg-opacity-75 text-white text-xs px-1.5 py-0.5 rounded"
            >
              {{ formatFileSize(image.size) }}
            </div>
          </div>
        </div>
      </div>

      <!-- Sections and Options - Grouped Together -->
      <div class="space-y-4">
        <div
          class="flex justify-between items-center mb-4 p-4 rounded-lg border-2 !border-green-600 !bg-green-50 dark:!bg-green-900/20"
        >
          <h4 class="text-lg font-bold !text-green-900 dark:!text-green-100">
            Sections & Options
          </h4>
          <button
            class="px-6 py-3 !bg-green-600 hover:!bg-green-700 !text-white rounded-lg transition-all font-bold shadow-lg hover:shadow-xl text-base"
            @click="addSection"
          >
            ➕ Add Section
          </button>
        </div>

        <!-- Each Section with its Options -->
        <div
          v-for="(section, sectionIndex) in listPickerData.sections"
          :key="sectionIndex"
          class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
        >
          <!-- Section Header -->
          <div class="flex items-start gap-3 mb-4">
            <div class="flex-1">
              <label
                class="block text-xs font-semibold text-n-slate-11 dark:text-n-slate-10 uppercase mb-2"
              >
                Section {{ sectionIndex + 1 }} Title
              </label>
              <input
                v-model="section.title"
                class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
                placeholder="Enter section title (e.g., iPhone, Accessories)"
              />
            </div>
            <button
              v-if="listPickerData.sections.length > 1"
              class="px-4 py-2 bg-n-ruby-9 dark:bg-n-ruby-10 text-white rounded-lg hover:bg-n-ruby-10 dark:hover:bg-n-ruby-11 transition-colors mt-6"
              @click="removeSection(sectionIndex)"
            >
              Remove Section
            </button>
          </div>

          <!-- Multiple Selection Checkbox -->
          <div class="mb-4 flex items-center gap-2">
            <input
              :id="`multipleSelection-${sectionIndex}`"
              v-model="section.multipleSelection"
              type="checkbox"
              class="w-4 h-4 text-n-blue-9 bg-n-solid-1 border-n-weak rounded focus:ring-n-blue-8 dark:focus:ring-n-blue-9 dark:ring-offset-n-alpha-1 focus:ring-2 dark:bg-n-alpha-2 dark:border-n-alpha-6"
              @change="
                console.log(
                  `[DEBUG] Checkbox changed for section ${sectionIndex}:`,
                  section.multipleSelection,
                  'Section object:',
                  section
                )
              "
            />
            <label
              :for="`multipleSelection-${sectionIndex}`"
              class="text-sm text-n-slate-12 dark:text-n-slate-11 cursor-pointer"
            >
              Allow multiple selections in this section
            </label>
          </div>

          <!-- Section Options -->
          <div class="space-y-2">
            <div
              v-for="(item, itemIndex) in section.items"
              :key="itemIndex"
              class="space-y-2"
            >
              <!-- Option Title and Description -->
              <div class="grid grid-cols-[1fr_1fr_auto] gap-2">
                <input
                  v-model="item.title"
                  class="px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 text-sm"
                  placeholder="Option title"
                />
                <input
                  v-model="item.subtitle"
                  class="px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9 text-sm"
                  placeholder="Description"
                />
                <button
                  class="px-3 py-2 bg-n-ruby-9 dark:bg-n-ruby-10 text-white rounded-lg hover:bg-n-ruby-10 dark:hover:bg-n-ruby-11 transition-colors text-sm"
                  @click="removeListItem(sectionIndex, itemIndex)"
                >
                  Remove
                </button>
              </div>

              <!-- Image Selection Row (Compact) -->
              <div
                class="flex items-center gap-2 px-3 py-2 bg-n-alpha-1 dark:bg-n-alpha-2 rounded-lg"
              >
                <span
                  class="text-xs text-n-slate-11 dark:text-n-slate-10 min-w-[80px]"
                >
                  Image:
                </span>

                <!-- Current image preview -->
                <div
                  v-if="
                    item.image_identifier &&
                    getImageByIdentifier(item.image_identifier)
                  "
                  class="flex items-center gap-2 flex-1"
                >
                  <img
                    :src="
                      getImageByIdentifier(item.image_identifier).preview ||
                      getImageByIdentifier(item.image_identifier).image_url
                    "
                    class="w-8 h-8 object-cover rounded border border-n-weak dark:border-n-alpha-6"
                    :alt="item.title"
                  />
                  <div
                    class="flex-1 text-xs text-n-slate-11 dark:text-n-slate-10 truncate"
                  >
                    {{
                      getImageByIdentifier(item.image_identifier)
                        .originalName ||
                      getImageByIdentifier(item.image_identifier).description
                    }}
                  </div>
                  <button
                    class="px-2 py-1 text-xs bg-n-slate-3 dark:bg-n-alpha-3 text-n-slate-11 dark:text-n-slate-10 rounded hover:bg-n-slate-4 dark:hover:bg-n-alpha-4"
                    @click="item.image_identifier = ''"
                  >
                    Clear
                  </button>
                </div>

                <!-- No image selected -->
                <span
                  v-else
                  class="flex-1 text-xs text-n-slate-10 dark:text-n-slate-9 italic"
                >
                  No image selected
                </span>

                <!-- Select image button -->
                <button
                  v-if="
                    listPickerData.images.length > 0 || savedImages.length > 0
                  "
                  class="px-2 py-1 text-xs bg-n-blue-9 dark:bg-n-blue-10 text-white rounded hover:bg-n-blue-10 dark:hover:bg-n-blue-11"
                  @click="openImagePicker(sectionIndex, itemIndex)"
                >
                  {{ item.image_identifier ? 'Change' : 'Select' }}
                </button>
                <span
                  v-else
                  class="text-xs text-n-slate-10 dark:text-n-slate-9 italic"
                >
                  Upload images first
                </span>
              </div>
            </div>

            <div
              v-if="section.items.length === 0"
              class="text-sm text-n-slate-10 dark:text-n-slate-9 italic py-3 text-center"
            >
              No options yet. Click "+ Add Option" to create items.
            </div>

            <button
              class="w-full px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors font-medium text-sm"
              @click="addListItem(sectionIndex)"
            >
              + Add Option
            </button>
          </div>
        </div>
      </div>

      <!-- Reply Message Configuration -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
        >
          Reply Message
        </h4>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Title</label
            >
            <input
              v-model="listPickerData.reply_title"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Selection Made"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Subtitle</label
            >
            <input
              v-model="listPickerData.reply_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Your selection"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Image Title</label
            >
            <input
              v-model="listPickerData.reply_image_title"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Optional image title"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Image Subtitle</label
            >
            <input
              v-model="listPickerData.reply_image_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Optional image subtitle"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Secondary Subtitle</label
            >
            <input
              v-model="listPickerData.reply_secondary_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Right-aligned title"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Tertiary Subtitle</label
            >
            <input
              v-model="listPickerData.reply_tertiary_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Right-aligned subtitle"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Style</label
            >
            <select
              v-model="listPickerData.reply_style"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
            >
              <option
                v-for="style in styleOptions"
                :key="style.value"
                :value="style.value"
              >
                {{ style.label }}
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Reply Tab -->
    <div v-if="activeTab === 'quick_reply'" class="space-y-4">
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <label
          class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
          >Question</label
        >
        <input
          v-model="quickReplyData.summary_text"
          class="w-full px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
          placeholder="Quick Reply Question"
        />
      </div>

      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6 space-y-2"
      >
        <label
          class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-2"
          >Reply Options (2-5)</label
        >
        <div
          v-for="(item, index) in quickReplyData.items"
          :key="index"
          class="flex space-x-2"
        >
          <input
            v-model="item.title"
            class="flex-1 px-3 py-2 border border-n-weak dark:border-n-alpha-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
            style="height: 40px"
            placeholder="Reply option"
          />
          <button
            class="px-3 py-2 bg-n-ruby-9 dark:bg-n-ruby-10 text-white dark:text-n-slate-12 rounded-lg hover:bg-n-ruby-10 dark:hover:bg-n-ruby-11 transition-colors"
            style="height: 40px"
            :disabled="quickReplyData.items.length <= 2"
            @click="removeQuickReplyItem(index)"
          >
            Remove
          </button>
        </div>

        <button
          class="w-full px-3 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors font-medium"
          :disabled="quickReplyData.items.length >= 5"
          @click="addQuickReplyItem"
        >
          + Add Option
        </button>
      </div>
    </div>

    <!-- Time Picker Tab -->
    <div v-if="activeTab === 'time_picker'" class="space-y-6">
      <!-- Images Management for Time Picker -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <div class="flex justify-between items-center mb-3">
          <h4
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Choose 1 image for the Time Picker
          </h4>
          <button
            v-if="timePickerImageSource === 'inline'"
            class="px-3 py-1 bg-n-blue-9 dark:bg-n-blue-10 text-white dark:text-n-slate-12 rounded text-sm hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors"
            @click="addImage"
          >
            Add Image
          </button>
        </div>

        <!-- Toggle: Inline vs Shared -->
        <div
          class="flex items-center gap-2 mb-3 p-2 bg-n-alpha-1 dark:bg-n-alpha-2 rounded-lg"
        >
          <button
            type="button"
            class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
            :class="
              timePickerImageSource === 'inline'
                ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
            "
            @click="timePickerImageSource = 'inline'"
          >
            Inline Images
          </button>
          <button
            type="button"
            class="flex-1 px-3 py-1.5 text-xs font-medium rounded transition-all"
            :class="
              timePickerImageSource === 'shared'
                ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
            "
            @click="timePickerImageSource = 'shared'"
          >
            Shared Images
          </button>
        </div>

        <!-- Inline Images Gallery (Saved + Uploaded) -->
        <div v-if="timePickerImageSource === 'inline'">
          <div class="grid grid-cols-6 gap-2 mb-4">
            <!-- Saved Images -->
            <div
              v-for="savedImage in savedImages"
              :key="`saved-${savedImage.id}`"
              class="relative group cursor-pointer aspect-square border-2 rounded-lg overflow-hidden transition-all"
              :class="
                timePickerData.receivedImageIdentifier === savedImage.identifier
                  ? 'border-n-blue-8 dark:border-n-blue-9 ring-2 ring-n-blue-8 dark:ring-n-blue-9'
                  : 'border-n-weak dark:border-n-slate-6 hover:border-n-blue-8 dark:hover:border-n-blue-9'
              "
              @click="selectTimePickerImage(savedImage.identifier)"
            >
              <img
                :src="savedImage.image_url"
                :alt="savedImage.description"
                class="w-full h-full object-cover"
              />
              <div
                v-if="
                  timePickerData.receivedImageIdentifier ===
                  savedImage.identifier
                "
                class="absolute top-1 right-1 bg-n-blue-9 text-white rounded-full p-1"
              >
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
            </div>

            <!-- Uploaded Images -->
            <div
              v-for="(image, index) in listPickerData.images"
              :key="`uploaded-${index}`"
              class="relative group cursor-pointer aspect-square border-2 rounded-lg overflow-hidden transition-all"
              :class="
                timePickerData.receivedImageIdentifier === image.identifier
                  ? 'border-n-blue-8 dark:border-n-blue-9 ring-2 ring-n-blue-8 dark:ring-n-blue-9'
                  : 'border-n-weak dark:border-n-slate-6 hover:border-n-blue-8 dark:hover:border-n-blue-9'
              "
              @click="selectTimePickerImage(image.identifier)"
            >
              <img
                v-if="image.preview"
                :src="image.preview"
                :alt="image.originalName || image.description"
                class="w-full h-full object-cover"
              />
              <div
                v-if="
                  timePickerData.receivedImageIdentifier === image.identifier
                "
                class="absolute top-1 right-1 bg-n-blue-9 text-white rounded-full p-1"
              >
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <button
                class="absolute top-1 left-1 bg-n-ruby-9 dark:bg-n-ruby-10 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                @click.stop="removeImage(index)"
              >
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                    clip-rule="evenodd"
                  />
                </svg>
              </button>
            </div>
          </div>

          <div
            v-if="
              savedImages.length === 0 && listPickerData.images.length === 0
            "
            class="text-sm text-n-slate-11 dark:text-n-slate-10 italic text-center py-4"
          >
            No images available. Click "Add Image" to upload.
          </div>
        </div>

        <!-- Shared Image Selector -->
        <div v-else-if="timePickerImageSource === 'shared'">
          <SharedImageSelector
            v-model="timePickerData.receivedImageIdentifier"
            :account-id="store.getters.getCurrentAccountId"
            image-type="system"
            @image-selected="handleTimePickerSharedImageSelected"
          />
        </div>
      </div>

      <!-- Received & Reply Message Configuration for Time Picker -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
        >
          Message Configuration
        </h4>
        <div class="space-y-4">
          <!-- Received Message -->
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Received Title</label
            >
            <input
              v-model="timePickerData.received_title"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Please pick a time"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Received Subtitle</label
            >
            <input
              v-model="timePickerData.received_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Select your preferred time slot"
            />
          </div>

          <!-- Received Style with Preview -->
          <div>
            <label
              class="block text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
              >Received Style</label
            >
            <div class="grid grid-cols-3 gap-3">
              <div
                v-for="style in styleOptions"
                :key="`received-${style.value}`"
                class="border-2 rounded-lg p-2 cursor-pointer transition-all duration-200 hover:shadow-md"
                :class="
                  timePickerData.received_style === style.value
                    ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                    : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
                "
                @click="timePickerData.received_style = style.value"
              >
                <div class="text-center">
                  <!-- Style Preview -->
                  <div
                    class="mx-auto mb-2 rounded border-2 bg-white dark:bg-n-alpha-2 flex items-center justify-center"
                    :class="
                      style.value === 'icon'
                        ? 'w-20 h-6'
                        : style.value === 'small'
                          ? 'w-20 h-8'
                          : 'w-20 h-16'
                    "
                  >
                    <img
                      v-if="
                        timePickerData.receivedImageIdentifier &&
                        getImagePreview(timePickerData.receivedImageIdentifier)
                      "
                      :src="
                        getImagePreview(timePickerData.receivedImageIdentifier)
                      "
                      class="w-full h-full object-contain rounded"
                      alt="Preview"
                    />
                    <svg
                      v-else
                      class="w-8 h-8 text-n-slate-8"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>

                  <p
                    class="font-medium text-sm text-n-slate-12 dark:text-n-slate-11"
                  >
                    {{ style.label }} ({{ style.dimensions }})
                  </p>

                  <!-- Selected indicator -->
                  <div
                    v-if="timePickerData.received_style === style.value"
                    class="mt-1 flex items-center justify-center text-n-blue-10 dark:text-n-blue-9"
                  >
                    <svg
                      class="w-5 h-5"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Reply Message -->
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Reply Title</label
            >
            <input
              v-model="timePickerData.reply_title"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder="Thank you!"
            />
          </div>
          <div>
            <label
              class="block text-sm font-medium text-n-slate-12 dark:text-n-slate-11 mb-1"
              >Reply Subtitle</label
            >
            <input
              v-model="timePickerData.reply_subtitle"
              class="w-full px-3 py-2 border border-n-weak dark:border-n-slate-6 rounded-lg bg-n-solid-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11 focus:border-n-blue-8 dark:focus:border-n-blue-9"
              placeholder=""
            />
          </div>

          <!-- Reply Style with Preview -->
          <div>
            <label
              class="block text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
              >Reply Style</label
            >
            <div class="grid grid-cols-3 gap-3">
              <div
                v-for="style in styleOptions"
                :key="`reply-${style.value}`"
                class="border-2 rounded-lg p-2 cursor-pointer transition-all duration-200 hover:shadow-md"
                :class="
                  timePickerData.reply_style === style.value
                    ? 'border-n-blue-8 bg-n-blue-1 dark:border-n-blue-9 dark:bg-n-blue-2'
                    : 'border-n-weak hover:border-n-blue-6 dark:border-n-slate-6 dark:hover:border-n-blue-7'
                "
                @click="timePickerData.reply_style = style.value"
              >
                <div class="text-center">
                  <!-- Style Preview -->
                  <div
                    class="mx-auto mb-2 rounded border-2 bg-white dark:bg-n-alpha-2 flex items-center justify-center"
                    :class="
                      style.value === 'icon'
                        ? 'w-20 h-6'
                        : style.value === 'small'
                          ? 'w-20 h-8'
                          : 'w-20 h-16'
                    "
                  >
                    <img
                      v-if="
                        timePickerData.receivedImageIdentifier &&
                        getImagePreview(timePickerData.receivedImageIdentifier)
                      "
                      :src="
                        getImagePreview(timePickerData.receivedImageIdentifier)
                      "
                      class="w-full h-full object-contain rounded"
                      alt="Preview"
                    />
                    <svg
                      v-else
                      class="w-8 h-8 text-n-slate-8"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>

                  <p
                    class="font-medium text-sm text-n-slate-12 dark:text-n-slate-11"
                  >
                    {{ style.label }} ({{ style.dimensions }})
                  </p>

                  <!-- Selected indicator -->
                  <div
                    v-if="timePickerData.reply_style === style.value"
                    class="mt-1 flex items-center justify-center text-n-blue-10 dark:text-n-blue-9"
                  >
                    <svg
                      class="w-5 h-5"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Inline Time Picker Interface -->
      <div class="space-y-4">
        <!-- Quick Settings -->
        <div class="flex items-center justify-between">
          <h4
            class="text-sm font-semibold"
            :class="
              selectedSlotsData.length > 0
                ? 'text-n-green-11 dark:text-n-green-10'
                : 'text-n-ruby-11 dark:text-n-ruby-10'
            "
          >
            Schedule Appointment - {{ selectedSlotsData.length }} slot(s)
            selected
            <span
              v-if="selectedSlotsData.length === 0"
              class="text-xs font-normal text-n-ruby-10 dark:text-n-ruby-9"
            >
              (click slots below to select)
            </span>
          </h4>
          <div class="flex items-center space-x-4">
            <!-- Time Interval Selector -->
            <div class="flex space-x-1">
              <button
                v-for="interval in intervalOptions"
                :key="interval.value"
                class="px-2 py-1 text-xs rounded transition-colors"
                :class="
                  inlineTimePickerData.selectedInterval === interval.value
                    ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                    : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 dark:bg-n-alpha-3 dark:text-n-slate-10'
                "
                @click="inlineTimePickerData.selectedInterval = interval.value"
              >
                {{ interval.icon }} {{ interval.label }}
              </button>
            </div>
            <!-- Advanced Settings Button -->
            <button
              class="px-3 py-1 text-xs bg-n-alpha-2 dark:bg-n-alpha-3 text-n-slate-11 dark:text-n-slate-10 rounded hover:bg-n-alpha-3 dark:hover:bg-n-alpha-4 transition-colors"
              @click="showEnhancedTimePicker = true"
            >
              Advanced
            </button>
          </div>
        </div>

        <!-- Date Navigation -->
        <div
          class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
        >
          <div class="flex items-center justify-between mb-3">
            <button
              class="flex items-center px-2 py-1 text-sm text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-3 rounded transition-colors"
              @click="navigateWeek('prev')"
            >
              <svg
                class="w-4 h-4 mr-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              Previous
            </button>

            <div
              class="text-sm font-medium text-n-slate-12 dark:text-n-slate-11"
            >
              {{ format(currentWeekStart, 'MMM d') }} -
              {{ format(addDays(currentWeekStart, 6), 'MMM d, yyyy') }}
            </div>

            <button
              class="flex items-center px-2 py-1 text-sm text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-3 rounded transition-colors"
              @click="navigateWeek('next')"
            >
              Next
              <svg
                class="w-4 h-4 ml-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 5l7 7-7 7"
                />
              </svg>
            </button>
          </div>

          <!-- Week View -->
          <div class="grid grid-cols-7 gap-1">
            <button
              v-for="day in weekDays"
              :key="day.date"
              class="p-2 text-center rounded transition-colors"
              :class="[
                day.isSelected
                  ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                  : day.isToday
                    ? 'bg-n-blue-2 text-n-blue-11 dark:bg-n-blue-3 dark:text-n-blue-10 border border-n-blue-6'
                    : day.hasSlots && !day.isPast
                      ? 'bg-n-alpha-1 text-n-slate-11 hover:bg-n-alpha-2 dark:bg-n-alpha-2 dark:text-n-slate-10 dark:hover:bg-n-alpha-3'
                      : 'bg-n-alpha-1 text-n-slate-9 cursor-not-allowed dark:bg-n-alpha-2 dark:text-n-slate-8 opacity-50',
              ]"
              :disabled="!day.hasSlots || day.isPast"
              @click="selectDate(day.date)"
            >
              <div class="text-xs font-medium">{{ day.dayName }}</div>
              <div class="text-sm">{{ day.displayDate }}</div>
            </button>
          </div>
        </div>

        <!-- Available Time Slots -->
        <div
          class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
        >
          <div class="flex items-center justify-between mb-3">
            <h4
              class="text-sm font-medium text-n-slate-12 dark:text-n-slate-11"
            >
              Available Slots for
              {{
                format(
                  new Date(inlineTimePickerData.selectedDate),
                  'MMM d, yyyy'
                )
              }}
            </h4>
            <div class="text-xs text-n-slate-11 dark:text-n-slate-10">
              {{ selectedSlotsData.length }} /
              {{ inlineTimePickerData.maxSlots }} selected
            </div>
          </div>

          <div v-if="availableSlots.length === 0" class="text-center py-4">
            <div class="text-sm text-n-slate-11 dark:text-n-slate-10">
              No available time slots for this date
            </div>
          </div>

          <div v-else class="grid grid-cols-3 gap-2 max-h-48 overflow-y-auto">
            <button
              v-for="slot in availableSlots"
              :key="slot.id"
              class="flex items-center justify-between p-2 rounded border transition-all duration-200 transform hover:scale-105"
              :class="[
                slot.selected
                  ? 'border-n-green-8 bg-n-green-2 text-n-green-11 dark:border-n-green-9 dark:bg-n-green-3 dark:text-n-green-10 shadow-md scale-105'
                  : 'border-n-weak bg-white hover:border-n-strong hover:bg-n-alpha-1 text-n-slate-11 dark:border-n-slate-6 dark:bg-n-alpha-2 dark:hover:bg-n-alpha-3 dark:text-n-slate-10 hover:shadow-sm',
              ]"
              :title="
                slot.selected
                  ? 'Click to deselect this time slot'
                  : 'Click to select this time slot'
              "
              @click="toggleSlot(slot)"
            >
              <div class="text-xs">
                <div class="font-medium">{{ slot.displayTime }}</div>
                <div class="opacity-75">{{ slot.duration }}min</div>
              </div>
              <div
                class="w-2 h-2 rounded-full"
                :class="slot.selected ? 'bg-n-green-9' : 'bg-n-blue-8'"
              />
            </button>
          </div>
        </div>

        <!-- Selected Slots Summary -->
        <div
          v-if="selectedSlotsData.length > 0"
          class="bg-n-green-1 dark:bg-n-green-2 p-3 rounded-lg border border-n-green-6 dark:border-n-green-7"
        >
          <h4
            class="text-sm font-medium text-n-green-11 dark:text-n-green-10 mb-2"
          >
            Selected Time Slots
          </h4>
          <div class="space-y-1">
            <div
              v-for="slot in selectedSlotsData"
              :key="slot.key"
              class="flex items-center justify-between text-xs text-n-green-10 dark:text-n-green-9"
            >
              <span
                >{{ format(new Date(slot.date), 'MMM d') }} at
                {{ slot.displayTime }} - {{ slot.displayEndTime }}</span
              >
              <button
                class="p-1 hover:bg-n-green-3 dark:hover:bg-n-green-4 rounded transition-colors"
                @click="toggleSlot(slot)"
              >
                <svg
                  class="w-3 h-3"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Forms Tab -->
    <div v-if="activeTab === 'forms'" class="space-y-6">
      <div class="text-center py-12">
        <div class="mb-6">
          <div
            class="w-16 h-16 bg-woot-100 dark:bg-woot-900 rounded-full flex items-center justify-center mx-auto mb-4"
          >
            <svg
              class="w-8 h-8 text-woot-600 dark:text-woot-400"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"
              />
            </svg>
          </div>
          <h3
            class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11 mb-2"
          >
            Create Interactive Forms
          </h3>
          <p
            class="text-sm text-n-slate-10 dark:text-n-slate-9 max-w-md mx-auto"
          >
            Build dynamic forms with multiple field types, validation, and
            templates. Perfect for surveys, contact forms, and data collection.
          </p>
        </div>

        <div class="flex flex-wrap gap-3 justify-center mb-6">
          <span
            class="px-3 py-1 bg-woot-50 dark:bg-woot-900 text-woot-700 dark:text-woot-300 text-xs rounded-full"
          >
            📝 Text Fields
          </span>
          <span
            class="px-3 py-1 bg-green-50 dark:bg-green-900/30 text-green-700 dark:text-green-300 text-xs rounded-full"
          >
            🔘 Single Choice
          </span>
          <span
            class="px-3 py-1 bg-purple-50 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 text-xs rounded-full"
          >
            ☑️ Multiple Choice
          </span>
          <span
            class="px-3 py-1 bg-orange-50 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300 text-xs rounded-full"
          >
            📅 Date & Time
          </span>
          <span
            class="px-3 py-1 bg-pink-50 dark:bg-pink-900/30 text-pink-700 dark:text-pink-300 text-xs rounded-full"
          >
            🔢 Number Stepper
          </span>
        </div>

        <button
          class="px-6 py-3 bg-woot-600 hover:bg-woot-700 text-white font-medium rounded-lg transition-colors"
          @click="openFormBuilder"
        >
          🛠️ Open Form Builder
        </button>
      </div>
    </div>

    <!-- iMessage Apps Tab -->
    <div v-if="activeTab === 'imessage_apps'" class="space-y-6">
      <!-- No Apps Configured Message -->
      <div v-if="availableApps.length === 0" class="text-center py-12">
        <div
          class="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mx-auto mb-4"
        >
          <svg
            class="w-8 h-8 text-slate-400"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"
            />
          </svg>
        </div>
        <h3
          class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11 mb-2"
        >
          No iMessage Apps Configured
        </h3>
        <p
          class="text-sm text-n-slate-10 dark:text-n-slate-9 max-w-md mx-auto mb-4"
        >
          Configure iMessage apps in your inbox settings to enable custom app
          invocations.
        </p>
        <p class="text-xs text-n-slate-9 dark:text-n-slate-8">
          Go to Settings → Inboxes → Your Apple Messages Channel → iMessage Apps
          Configuration
        </p>
      </div>

      <!-- App Selection -->
      <div v-else>
        <div class="mb-6">
          <h4
            class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
          >
            Select iMessage App
          </h4>
          <div class="space-y-2">
            <label
              v-for="app in availableApps"
              :key="app.id"
              class="flex items-center space-x-3 p-3 border border-n-weak rounded-lg cursor-pointer hover:bg-n-alpha-2 transition-colors"
              :class="
                selectedAppId === app.id ? 'border-n-woot-8 bg-n-woot-1' : ''
              "
            >
              <input
                v-model="selectedAppId"
                type="radio"
                :value="app.id"
                class="rounded-full border-n-weak text-n-woot-8 focus:ring-n-woot-8"
              />
              <div class="flex-1">
                <div class="font-medium text-n-slate-12 dark:text-n-slate-11">
                  {{ app.name }}
                </div>
                <div class="text-sm text-n-slate-10 dark:text-n-slate-9">
                  {{ app.description }}
                </div>
                <div
                  class="text-xs text-n-slate-8 dark:text-n-slate-7 font-mono mt-1"
                >
                  {{ app.app_id }}
                </div>
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- OAuth Tab -->
    <div v-if="activeTab === 'oauth'" class="space-y-6">
      <div class="text-center py-12">
        <div
          class="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mx-auto mb-4"
        >
          <svg
            class="w-8 h-8 text-slate-400"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z"
            />
          </svg>
        </div>
        <h3
          class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11 mb-2"
        >
          OAuth Authentication
        </h3>
        <p
          class="text-sm text-n-slate-10 dark:text-n-slate-9 max-w-md mx-auto mb-4"
        >
          OAuth authentication for Apple Messages for Business is coming soon.
        </p>
        <p class="text-xs text-n-slate-9 dark:text-n-slate-8">
          This feature will allow secure authentication flows within iMessage.
        </p>
      </div>
    </div>

    <!-- Apple Pay Tab -->
    <div v-if="activeTab === 'apple_pay'" class="space-y-6">
      <!-- Payment Templates Selector -->
      <div
        class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
      >
        <h4
          class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
        >
          Payment Templates
        </h4>
        <p class="text-xs text-n-slate-11 dark:text-n-slate-10 mb-4">
          Select a template to quickly test Apple Pay functionality
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <!-- Template 1 - Simple Product -->
          <button
            class="text-left p-4 border border-n-weak dark:border-n-slate-6 rounded-lg hover:border-n-blue-8 dark:hover:border-n-blue-9 hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-all"
            @click="loadPaymentTemplate('simple')"
          >
            <div class="flex items-start space-x-3">
              <div
                class="w-10 h-10 bg-n-blue-2 dark:bg-n-blue-3 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <span class="text-xl">📦</span>
              </div>
              <div class="flex-1">
                <h5
                  class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-1"
                >
                  Simple Product
                </h5>
                <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mb-2">
                  Single item purchase - $10.00
                </p>
                <div class="flex items-center space-x-2 text-xs">
                  <span
                    class="px-2 py-0.5 bg-n-green-2 dark:bg-n-green-3 text-n-green-11 dark:text-n-green-10 rounded"
                    >USD</span
                  >
                  <span
                    class="px-2 py-0.5 bg-n-blue-2 dark:bg-n-blue-3 text-n-blue-11 dark:text-n-blue-10 rounded"
                    >No Shipping</span
                  >
                </div>
              </div>
            </div>
          </button>

          <!-- Template 2 - Product with Shipping -->
          <button
            class="text-left p-4 border border-n-weak dark:border-n-slate-6 rounded-lg hover:border-n-blue-8 dark:hover:border-n-blue-9 hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-all"
            @click="loadPaymentTemplate('shipping')"
          >
            <div class="flex items-start space-x-3">
              <div
                class="w-10 h-10 bg-n-purple-2 dark:bg-n-purple-3 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <span class="text-xl">🎧</span>
              </div>
              <div class="flex-1">
                <h5
                  class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-1"
                >
                  Product with Shipping
                </h5>
                <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mb-2">
                  Wireless Headphones with tax & shipping - $112.99
                </p>
                <div class="flex items-center space-x-2 text-xs">
                  <span
                    class="px-2 py-0.5 bg-n-green-2 dark:bg-n-green-3 text-n-green-11 dark:text-n-green-10 rounded"
                    >USD</span
                  >
                  <span
                    class="px-2 py-0.5 bg-n-purple-2 dark:bg-n-purple-3 text-n-purple-11 dark:text-n-purple-10 rounded"
                    >Requires Shipping</span
                  >
                </div>
              </div>
            </div>
          </button>

          <!-- Template 3 - Service Booking -->
          <button
            class="text-left p-4 border border-n-weak dark:border-n-slate-6 rounded-lg hover:border-n-blue-8 dark:hover:border-n-blue-9 hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-all"
            @click="loadPaymentTemplate('service')"
          >
            <div class="flex items-start space-x-3">
              <div
                class="w-10 h-10 bg-n-pink-2 dark:bg-n-pink-3 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <span class="text-xl">💆</span>
              </div>
              <div class="flex-1">
                <h5
                  class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-1"
                >
                  Service Booking
                </h5>
                <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mb-2">
                  Spa service with fee - $90.00
                </p>
                <div class="flex items-center space-x-2 text-xs">
                  <span
                    class="px-2 py-0.5 bg-n-green-2 dark:bg-n-green-3 text-n-green-11 dark:text-n-green-10 rounded"
                    >USD</span
                  >
                  <span
                    class="px-2 py-0.5 bg-n-orange-2 dark:bg-n-orange-3 text-n-orange-11 dark:text-n-orange-10 rounded"
                    >Billing Required</span
                  >
                </div>
              </div>
            </div>
          </button>

          <!-- Template 4 - Multi-Currency (EUR) -->
          <button
            class="text-left p-4 border border-n-weak dark:border-n-slate-6 rounded-lg hover:border-n-blue-8 dark:hover:border-n-blue-9 hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-all"
            @click="loadPaymentTemplate('euro')"
          >
            <div class="flex items-start space-x-3">
              <div
                class="w-10 h-10 bg-n-amber-2 dark:bg-n-amber-3 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <span class="text-xl">💎</span>
              </div>
              <div class="flex-1">
                <h5
                  class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-1"
                >
                  Premium Product (EUR)
                </h5>
                <p class="text-xs text-n-slate-10 dark:text-n-slate-9 mb-2">
                  European Shop - €149.99
                </p>
                <div class="flex items-center space-x-2 text-xs">
                  <span
                    class="px-2 py-0.5 bg-n-amber-2 dark:bg-n-amber-3 text-n-amber-11 dark:text-n-amber-10 rounded"
                    >EUR</span
                  >
                  <span
                    class="px-2 py-0.5 bg-n-blue-2 dark:bg-n-blue-3 text-n-blue-11 dark:text-n-blue-10 rounded"
                    >Germany</span
                  >
                </div>
              </div>
            </div>
          </button>
        </div>
      </div>

      <!-- Coming Soon Message -->
      <div class="text-center py-12">
        <div
          class="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mx-auto mb-4"
        >
          <svg
            class="w-8 h-8 text-slate-400"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              d="M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z"
            />
          </svg>
        </div>
        <h3
          class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11 mb-2"
        >
          Apple Pay Integration
        </h3>
        <p
          class="text-sm text-n-slate-10 dark:text-n-slate-9 max-w-md mx-auto mb-4"
        >
          Apple Pay integration for Apple Messages for Business is coming soon.
        </p>
        <p class="text-xs text-n-slate-9 dark:text-n-slate-8">
          Click a template above to quickly send a test payment to your device.
        </p>
      </div>
    </div>

    <!-- Custom Payload Tab -->
    <div v-if="activeTab === 'custom_payload'" class="space-y-6 max-w-none">
      <div class="grid grid-cols-1 xl:grid-cols-5 gap-6">
        <!-- Editor Section (Left) - Takes 3/5 of width -->
        <div class="custom-payload-editor space-y-4 xl:col-span-3">
          <div>
            <label
              class="block text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-2"
            >
              Custom Payload JSON
            </label>
            <textarea
              v-model="customPayloadData.payload"
              class="w-full h-96 p-4 font-mono text-sm border rounded-lg bg-n-slate-1 dark:bg-n-alpha-2 text-n-slate-12 dark:text-n-slate-11"
              :class="{
                'border-red-500': jsonValidationError,
                'border-green-500': isValidJson && !jsonValidationError,
                'border-n-weak dark:border-n-slate-6':
                  !jsonValidationError && !isValidJson,
              }"
              placeholder='{
  "type": "richLink",
  "richLinkData": {
    "url": "https://www.example.com/order/12345",
    "title": "Order Tracking",
    "assets": {
      "image": {
        "data": "base64_encoded_image_data_here",
        "mimeType": "image/png"
      }
    }
  }
}'
            />

            <div v-if="jsonValidationError" class="text-red-500 text-sm mt-2">
              ❌ {{ jsonValidationError }}
            </div>

            <div
              v-if="isValidJson && !jsonValidationError"
              class="text-green-500 text-sm mt-2"
            >
              ✅ Valid JSON
            </div>
          </div>

          <!-- Error Display Component -->
          <div
            v-if="sendError"
            class="error-display mt-4 p-4 rounded-lg border"
            :class="{
              'bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-800':
                sendError.type !== 'warning',
              'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-800':
                sendError.type === 'warning',
            }"
          >
            <!-- Error Header -->
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0">
                <span v-if="sendError.type === 'validation'" class="text-2xl">
                  ❌
                </span>
                <span
                  v-else-if="sendError.type === 'send_error'"
                  class="text-2xl"
                  >⚠️</span
                >
                <span
                  v-else-if="sendError.type === 'apple_error'"
                  class="text-2xl"
                  >🚫</span
                >
                <span v-else class="text-2xl">⚠️</span>
              </div>

              <div class="flex-1">
                <!-- Error Title -->
                <h4
                  class="font-semibold text-sm"
                  :class="{
                    'text-red-800 dark:text-red-300':
                      sendError.type !== 'warning',
                    'text-yellow-800 dark:text-yellow-300':
                      sendError.type === 'warning',
                  }"
                >
                  {{ getErrorTitle(sendError.type) }}
                </h4>

                <!-- Error Message -->
                <p
                  class="text-sm mt-1"
                  :class="{
                    'text-red-700 dark:text-red-400':
                      sendError.type !== 'warning',
                    'text-yellow-700 dark:text-yellow-400':
                      sendError.type === 'warning',
                  }"
                >
                  {{ sendError.message }}
                </p>

                <!-- Error Details (Expandable) -->
                <div v-if="sendError.details" class="mt-2">
                  <button
                    class="text-xs font-medium underline"
                    :class="{
                      'text-red-600 dark:text-red-400':
                        sendError.type !== 'warning',
                      'text-yellow-600 dark:text-yellow-400':
                        sendError.type === 'warning',
                    }"
                    @click="showErrorDetails = !showErrorDetails"
                  >
                    {{ showErrorDetails ? '▼ Hide' : '▶ Show' }} Details
                  </button>

                  <pre
                    v-if="showErrorDetails"
                    class="mt-2 p-3 bg-white dark:bg-n-slate-1 rounded text-xs font-mono overflow-auto max-h-40 border border-red-200 dark:border-red-800"
                    >{{ sendError.details }}</pre
                  >
                </div>

                <!-- Apple MSP Error (if present) -->
                <div
                  v-if="sendError.appleError"
                  class="mt-3 p-3 bg-red-100 dark:bg-red-950/50 rounded-lg border border-red-300 dark:border-red-800"
                >
                  <p
                    class="text-xs font-semibold text-red-900 dark:text-red-300 mb-1"
                  >
                    Apple MSP Gateway Error:
                  </p>
                  <p class="text-xs text-red-800 dark:text-red-400">
                    <strong>Status:</strong>
                    {{ sendError.appleError.status || 'Unknown' }}
                  </p>
                  <p class="text-xs text-red-800 dark:text-red-400">
                    <strong>Message:</strong>
                    {{ sendError.appleError.message || 'Unknown error' }}
                  </p>

                  <!-- Apple Error Body (if available) -->
                  <details v-if="sendError.appleError.body" class="mt-2">
                    <summary
                      class="text-xs font-medium text-red-700 dark:text-red-400 cursor-pointer"
                    >
                      View Apple Response Body
                    </summary>
                    <pre
                      class="mt-2 p-2 bg-white dark:bg-n-slate-1 rounded text-xs font-mono overflow-auto max-h-32 border border-red-200 dark:border-red-800"
                      >{{ sendError.appleError.body }}</pre
                    >
                  </details>
                </div>

                <!-- Suggested Actions -->
                <div v-if="sendError.suggestions" class="mt-3">
                  <p
                    class="text-xs font-semibold"
                    :class="{
                      'text-red-800 dark:text-red-300':
                        sendError.type !== 'warning',
                      'text-yellow-800 dark:text-yellow-300':
                        sendError.type === 'warning',
                    }"
                  >
                    Suggested Actions:
                  </p>
                  <ul
                    class="list-disc list-inside text-xs mt-1 space-y-1"
                    :class="{
                      'text-red-700 dark:text-red-400':
                        sendError.type !== 'warning',
                      'text-yellow-700 dark:text-yellow-400':
                        sendError.type === 'warning',
                    }"
                  >
                    <li
                      v-for="suggestion in sendError.suggestions"
                      :key="suggestion"
                    >
                      {{ suggestion }}
                    </li>
                  </ul>
                </div>
              </div>

              <!-- Close Button -->
              <button
                class="flex-shrink-0 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                @click="sendError = null"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
          </div>

          <!-- Validation Controls and Action Buttons - All in one row -->
          <div class="flex flex-wrap items-center gap-4">
            <!-- Validation Toggles -->
            <label class="flex items-center space-x-2 cursor-pointer">
              <input
                v-model="customPayloadData.skipValidation"
                type="checkbox"
                class="checkbox w-4 h-4 text-n-blue-9 bg-n-solid-1 border-n-weak rounded focus:ring-n-blue-8 dark:focus:ring-n-blue-9 dark:ring-offset-n-alpha-1 focus:ring-2 dark:bg-n-alpha-2 dark:border-n-alpha-6"
              />
              <span
                class="text-sm text-n-slate-12 dark:text-n-slate-11 whitespace-nowrap"
              >
                Allow experimental payloads
              </span>
            </label>

            <label class="flex items-center space-x-2 cursor-pointer">
              <input
                v-model="customPayloadData.applyCaseTransform"
                type="checkbox"
                class="checkbox w-4 h-4 text-n-blue-9 bg-n-solid-1 border-n-weak rounded focus:ring-n-blue-8 dark:focus:ring-n-blue-9 dark:ring-offset-n-alpha-1 focus:ring-2 dark:bg-n-alpha-2 dark:border-n-alpha-6"
              />
              <span
                class="text-sm text-n-slate-12 dark:text-n-slate-11 whitespace-nowrap"
              >
                Auto-apply case transformation
              </span>
            </label>

            <!-- Action Buttons -->
            <div class="flex space-x-3 ml-auto">
              <button
                type="button"
                class="px-4 py-2 border border-n-weak dark:border-n-slate-6 text-n-slate-11 dark:text-n-slate-10 rounded-lg hover:bg-n-alpha-2 dark:hover:bg-n-alpha-3 transition-colors"
                :disabled="!isValidJson && !customPayloadData.skipValidation"
                @click="validateCustomPayload"
              >
                Validate
              </button>

              <button
                type="button"
                class="px-4 py-2 bg-n-blue-9 dark:bg-n-blue-10 text-white rounded-lg hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap"
                :disabled="
                  (!isValidJson && !customPayloadData.skipValidation) ||
                  isSending
                "
                @click="sendCustomPayload"
              >
                {{ isSending ? 'Sending...' : 'Send Custom Payload' }}
              </button>
            </div>
          </div>

          <!-- Warning message for experimental mode -->
          <div
            v-if="customPayloadData.skipValidation"
            class="text-yellow-600 dark:text-yellow-400 text-sm p-3 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg"
          >
            ⚠️ <strong>Warning:</strong> Experimental mode bypasses validation.
            Invalid payloads may fail at Apple's gateway.
          </div>
        </div>

        <!-- Preview Section (Right) - Takes 2/5 of width -->
        <div class="preview-section space-y-4 xl:col-span-2">
          <div
            class="bg-n-alpha-2 dark:bg-n-alpha-3 p-4 rounded-lg border border-n-weak dark:border-n-slate-6"
          >
            <h4
              class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
            >
              Final Payload Preview
            </h4>

            <pre
              class="font-mono text-xs bg-n-slate-1 dark:bg-n-alpha-2 p-4 rounded-lg overflow-auto max-h-96 text-n-slate-12 dark:text-n-slate-11"
              >{{ previewPayload }}</pre
            >
          </div>

          <div
            class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg text-sm border border-blue-200 dark:border-blue-800"
          >
            <p class="font-semibold text-blue-900 dark:text-blue-300 mb-2">
              Auto-populated fields:
            </p>
            <ul
              class="list-disc list-inside space-y-1 text-blue-800 dark:text-blue-400"
            >
              <li>
                <code class="font-mono text-xs">v</code>: API version (always 1)
              </li>
              <li>
                <code class="font-mono text-xs">id</code>: Unique message ID
                (generated on send)
              </li>
              <li>
                <code class="font-mono text-xs">sourceId</code>: Your business
                ID
              </li>
              <li>
                <code class="font-mono text-xs">destinationId</code>: Contact ID
                (from conversation)
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>

    <!-- Actions - Positioned at the bottom for all tabs except Forms and Custom Payload -->
    <div
      v-if="activeTab !== 'forms' && activeTab !== 'custom_payload'"
      class="flex justify-end space-x-3 mt-6 pt-4 border-t border-n-weak dark:border-n-slate-6"
    >
      <button
        class="px-4 py-2 text-n-slate-11 dark:text-n-slate-10 hover:text-n-slate-12 dark:hover:text-n-slate-9 transition-colors"
        @click="cancelComposer"
      >
        Cancel
      </button>
      <button
        v-if="['quick_reply', 'list_picker', 'time_picker'].includes(activeTab)"
        class="px-4 py-2 border border-n-blue-9 dark:border-n-blue-10 text-n-blue-9 dark:text-n-blue-10 rounded-lg hover:bg-n-blue-1 dark:hover:bg-n-blue-2 transition-colors"
        @click="saveAsTemplate"
      >
        Save as Template
      </button>
      <button
        class="px-4 py-2 bg-n-blue-9 dark:bg-n-blue-10 text-white dark:text-n-slate-12 rounded-lg hover:bg-n-blue-10 dark:hover:bg-n-blue-11 transition-colors"
        @click="sendAppleMessage"
      >
        Send Message
      </button>
    </div>

    <!-- Enhanced Time Picker Modal -->
    <EnhancedTimePickerModal
      :show="showEnhancedTimePicker"
      :initial-data="timePickerData"
      :available-images="[...listPickerData.images, ...savedImages]"
      :inbox-id="conversation?.inbox_id"
      :account-id="store.getters.getCurrentAccountId"
      :business-hours="{
        monday: { start: '09:00', end: '17:00', enabled: true },
        tuesday: { start: '09:00', end: '17:00', enabled: true },
        wednesday: { start: '09:00', end: '17:00', enabled: true },
        thursday: { start: '09:00', end: '17:00', enabled: true },
        friday: { start: '09:00', end: '17:00', enabled: true },
        saturday: { start: '10:00', end: '16:00', enabled: false },
        sunday: { start: '10:00', end: '16:00', enabled: false },
      }"
      :timezone="Intl.DateTimeFormat().resolvedOptions().timeZone"
      :existing-bookings="[]"
      :service-duration="60"
      @close="showEnhancedTimePicker = false"
      @save="handleEnhancedTimePickerSave"
      @preview="handleEnhancedTimePickerPreview"
      @save-and-send="handleEnhancedTimePickerSaveAndSend"
      @upload-image="handleImageUpload"
      @save-as-template="handleEnhancedTimePickerSaveAsTemplate"
    />

    <!-- Apple Form Builder Modal -->
    <AppleFormBuilder
      :show="showFormBuilder"
      :available-images="savedImages"
      :inbox-id="conversation?.inbox_id"
      :msp-id="conversation?.inbox?.channel?.business_id || ''"
      :conversation-id="conversation?.id?.toString() || ''"
      @close="closeFormBuilder"
      @create="handleFormCreated"
      @upload-image="handleFormImageUpload"
      @save-as-template="handleFormSaveAsTemplate"
    />

    <!-- Save As Template Modal -->
    <SaveAsTemplateModal
      v-if="pendingTemplateData"
      :show="showSaveAsTemplateModal"
      :message-type="pendingTemplateData.messageType"
      :message-data="pendingTemplateData.messageData"
      @close="closeTemplateModal"
      @save="handleTemplateSave"
      @save-and-send="handleTemplateSaveAndSend"
    />

    <!-- Image Picker Modal -->
    <div
      v-if="showImagePicker"
      class="fixed inset-0 z-[9999] flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm"
      @click.self="closeImagePicker"
    >
      <div
        class="bg-n-solid-1 dark:bg-n-slate-1 rounded-lg shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-y-auto m-4 border-2 border-n-weak dark:border-n-alpha-6"
        style="
          box-shadow:
            0 25px 50px -12px rgba(0, 0, 0, 0.5),
            0 0 0 1px rgba(0, 0, 0, 0.1);
        "
      >
        <div
          class="sticky top-0 bg-n-solid-1 dark:bg-n-slate-1 border-b border-n-weak dark:border-n-alpha-6 p-4 flex justify-between items-center z-10 shadow-md"
        >
          <h3
            class="text-lg font-semibold text-n-slate-12 dark:text-n-slate-11"
          >
            Select Image
          </h3>
          <button
            class="text-n-slate-11 dark:text-n-slate-10 hover:text-n-slate-12 dark:hover:text-n-slate-9"
            @click="closeImagePicker"
          >
            ✕
          </button>
        </div>

        <div class="p-4">
          <!-- Toggle: Inline vs Shared -->
          <div
            class="flex items-center gap-2 mb-4 p-2 bg-n-alpha-1 dark:bg-n-alpha-2 rounded-lg"
          >
            <button
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium rounded transition-all"
              :class="
                imagePickerSource === 'inline'
                  ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                  : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
              "
              @click="imagePickerSource = 'inline'"
            >
              Inline Images
            </button>
            <button
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium rounded transition-all"
              :class="
                imagePickerSource === 'shared'
                  ? 'bg-n-blue-9 text-white dark:bg-n-blue-10'
                  : 'text-n-slate-11 hover:text-n-slate-12 dark:text-n-slate-10 dark:hover:text-n-slate-9'
              "
              @click="imagePickerSource = 'shared'"
            >
              Shared Images
            </button>
          </div>

          <!-- Inline Images View -->
          <div v-if="imagePickerSource === 'inline'">
            <!-- Recently uploaded images -->
            <div v-if="listPickerData.images.length > 0" class="mb-6">
              <h4
                class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
              >
                Recently Uploaded
              </h4>
              <div class="grid grid-cols-3 gap-3">
                <div
                  v-for="image in listPickerData.images"
                  :key="image.identifier"
                  class="relative cursor-pointer border-2 border-transparent hover:border-n-blue-8 dark:hover:border-n-blue-9 rounded-lg overflow-hidden transition-all"
                  @click="selectImageForItem(image)"
                >
                  <img
                    :src="image.preview"
                    :alt="image.description"
                    class="w-full h-32 object-cover"
                  />
                  <div
                    class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-95 text-white text-xs p-2 truncate shadow-lg"
                  >
                    {{ image.originalName || image.description }}
                  </div>
                </div>
              </div>
            </div>

            <!-- Saved images -->
            <div v-if="savedImages.length > 0">
              <h4
                class="text-sm font-semibold text-n-slate-12 dark:text-n-slate-11 mb-3"
              >
                Saved Images
              </h4>
              <div class="grid grid-cols-3 gap-3">
                <div
                  v-for="image in savedImages"
                  :key="image.id"
                  class="relative cursor-pointer border-2 border-transparent hover:border-n-blue-8 dark:hover:border-n-blue-9 rounded-lg overflow-hidden transition-all"
                  @click="selectImageForItem(image)"
                >
                  <img
                    :src="image.image_url"
                    :alt="image.description"
                    class="w-full h-32 object-cover"
                  />
                  <div
                    class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-95 text-white text-xs p-2 truncate shadow-lg"
                  >
                    {{ image.original_name || image.description }}
                  </div>
                </div>
              </div>
            </div>

            <!-- No images -->
            <div
              v-if="
                listPickerData.images.length === 0 && savedImages.length === 0
              "
              class="text-center py-8 text-n-slate-10 dark:text-n-slate-9"
            >
              <p>
                No images available. Upload images using the "Add Image" button
                above.
              </p>
            </div>
          </div>

          <!-- Shared Images View -->
          <div v-else-if="imagePickerSource === 'shared'">
            <SharedImageSelector
              model-value=""
              :account-id="store.getters.getCurrentAccountId"
              image-type="system"
              @image-selected="handleModalSharedImageSelected"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
