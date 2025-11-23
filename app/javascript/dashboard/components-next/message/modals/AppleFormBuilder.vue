<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import SharedImageSelector from 'dashboard/routes/dashboard/settings/templates/components/SharedImageSelector.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  availableImages: {
    type: Array,
    default: () => [],
  },
  accountId: {
    type: Number,
    required: false,
    default: null,
  },
});

const emit = defineEmits(['close', 'create', 'saveAsTemplate']);

const { t: i18nT } = useI18n();
const store = useStore();

// Safe translation wrapper to prevent vue-i18n parsing errors
const t = (key, defaultValue = '') => {
  try {
    return i18nT(key);
  } catch (error) {
    // Return the key itself as fallback
    return defaultValue || key.split('.').pop();
  }
};

// Computed properties for account ID
const currentAccountId = computed(() => {
  return props.accountId || store.getters.getCurrentAccountId;
});

// Form builder state
const formData = ref({
  title: '',
  description: '',
  pages: [],
  receivedMessage: {
    title: '',
    subtitle: '',
    imageIdentifier: '',
    style: 'large',
  },
  replyMessage: {
    title: '',
    subtitle: '',
    imageIdentifier: '',
    style: 'large',
  },
});

const activeTab = ref('templates'); // 'builder', 'preview', 'templates', 'messages'
const selectedTemplate = ref(null);
const currentPageIndex = ref(0);
const showAddFieldModal = ref(false);

// Automatically sync reply image with received image
watch(
  () => formData.value.receivedMessage?.imageIdentifier,
  newIdentifier => {
    // When received image changes, automatically update reply image to match
    if (formData.value.replyMessage) {
      formData.value.replyMessage.imageIdentifier = newIdentifier || '';
    }
  },
  { immediate: true }
);

// Automatically sync received message title with form title
watch(
  () => formData.value.title,
  newTitle => {
    if (formData.value.receivedMessage) {
      formData.value.receivedMessage.title = newTitle || '';
    }
  },
  { immediate: true }
);

// Automatically sync received message subtitle with form description
watch(
  () => formData.value.description,
  newDescription => {
    // Only sync if receivedMessage.subtitle is empty or matches the old description
    // This allows users to override the subtitle if they want
    if (
      formData.value.receivedMessage &&
      (!formData.value.receivedMessage.subtitle ||
        formData.value.receivedMessage.subtitle === formData.value.description)
    ) {
      formData.value.receivedMessage.subtitle = newDescription || '';
    }
  },
  { immediate: true }
);

// Helper to get image URL by identifier
const getImageByIdentifier = identifier => {
  if (!identifier) return null;
  return props.availableImages.find(img => img.identifier === identifier);
};

const getImagePreviewUrl = identifier => {
  const image = getImageByIdentifier(identifier);
  if (!image) return null;
  return image.preview || image.image_url;
};

// Apple MSP style options
const styleOptions = [
  { value: 'icon', label: 'Icon (280x65)' },
  { value: 'small', label: 'Small (280x85)' },
  { value: 'large', label: 'Large (280x210)' },
];

// Field types configuration - use computed to ensure i18n is ready
const fieldTypes = computed(() => {
  // Ensure i18n is fully loaded before accessing translations
  if (!t) return [];

  return [
    {
      value: 'text',
      label: t('APPLE_FORM.FIELD_TYPES.TEXT'),
      icon: '📝',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TEXT'),
    },
    {
      value: 'textArea',
      label: t('APPLE_FORM.FIELD_TYPES.TEXT_AREA'),
      icon: '📄',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TEXT_AREA'),
    },
    {
      value: 'email',
      label: t('APPLE_FORM.FIELD_TYPES.EMAIL'),
      icon: '📧',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.EMAIL'),
    },
    {
      value: 'phone',
      label: t('APPLE_FORM.FIELD_TYPES.PHONE'),
      icon: '📱',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.PHONE'),
    },
    {
      value: 'singleSelect',
      label: t('APPLE_FORM.FIELD_TYPES.SINGLE_CHOICE'),
      icon: '🔘',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.SINGLE_CHOICE'),
    },
    {
      value: 'multiSelect',
      label: t('APPLE_FORM.FIELD_TYPES.MULTIPLE_CHOICE'),
      icon: '☑️',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.MULTIPLE_CHOICE'),
    },
    {
      value: 'dateTime',
      label: t('APPLE_FORM.FIELD_TYPES.DATE_TIME'),
      icon: '📅',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.DATE_TIME'),
    },
    {
      value: 'toggle',
      label: t('APPLE_FORM.FIELD_TYPES.TOGGLE'),
      icon: '🔄',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.TOGGLE'),
    },
    {
      value: 'stepper',
      label: t('APPLE_FORM.FIELD_TYPES.STEPPER'),
      icon: '🔢',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.STEPPER'),
    },
    {
      value: 'richLink',
      label: t('APPLE_FORM.FIELD_TYPES.RICH_LINK'),
      icon: '🔗',
      description: t('APPLE_FORM.FIELD_DESCRIPTIONS.RICH_LINK'),
    },
  ];
});

// Form templates - use computed to ensure i18n is ready
const formTemplates = computed(() => {
  // Ensure i18n is fully loaded before accessing translations
  if (!t) return [];

  return [
    {
      id: 'contact',
      name: t('APPLE_FORM.TEMPLATES.CONTACT.NAME'),
      description: t('APPLE_FORM.TEMPLATES.CONTACT.DESCRIPTION'),
      icon: '👤',
      fields: ['name', 'email', 'phone', 'message'],
    },
    {
      id: 'feedback',
      name: t('APPLE_FORM.TEMPLATES.FEEDBACK.NAME'),
      description: t('APPLE_FORM.TEMPLATES.FEEDBACK.DESCRIPTION'),
      icon: '⭐',
      fields: ['rating', 'comments', 'recommend'],
    },
    {
      id: 'appointment',
      name: t('APPLE_FORM.TEMPLATES.APPOINTMENT.NAME'),
      description: t('APPLE_FORM.TEMPLATES.APPOINTMENT.DESCRIPTION'),
      icon: '📅',
      fields: ['name', 'date', 'service', 'notes'],
    },
    {
      id: 'survey',
      name: t('APPLE_FORM.TEMPLATES.SURVEY.NAME'),
      description: t('APPLE_FORM.TEMPLATES.SURVEY.DESCRIPTION'),
      icon: '📊',
      fields: ['demographics', 'preferences', 'satisfaction'],
    },
    {
      id: 'order',
      name: t('APPLE_FORM.TEMPLATES.ORDER.NAME'),
      description: t('APPLE_FORM.TEMPLATES.ORDER.DESCRIPTION'),
      icon: '🛒',
      fields: ['product', 'quantity', 'billing', 'terms'],
    },
  ];
});

// New field data
const newField = ref({
  item_id: '',
  item_type: 'text',
  title: '',
  description: '',
  required: false,
  placeholder: '',
  options: [{ value: '', title: '' }],
  min_value: 1,
  max_value: 10,
  max_length: null,
  url: '',
  default_value: '',
  keyboard_type: 'default',
  text_content_type: '',
  // Input field options (Apple MSP API)
  regex: '',
  input_type: 'singleline', // singleline or multiline
  label_text: '',
  prefix_text: '',
  maximum_character_count: null,
  hint_text: '',
  // DatePicker options
  date_format: 'MM/dd/yyyy',
  start_date: '',
  maximum_date: '',
  minimum_date: '',
  // Picker options
  picker_title: '',
  selected_item_index: 0,
  // Select options
  multiple_selection: false,
});

// Computed properties
const currentPage = computed(() => {
  if (!formData.value.pages || formData.value.pages.length === 0) {
    return null;
  }
  return formData.value.pages[currentPageIndex.value];
});

const canCreateForm = computed(() => {
  return (
    formData.value.title.trim().length > 0 &&
    formData.value.pages.length > 0 &&
    formData.value.pages.some(page => page.items && page.items.length > 0)
  );
});

const totalFields = computed(() => {
  return formData.value.pages.reduce((total, page) => {
    return total + (page.items ? page.items.length : 0);
  }, 0);
});

// Methods
const resetNewField = () => {
  newField.value = {
    item_id: '',
    item_type: 'text',
    title: '',
    description: '',
    required: false,
    placeholder: '',
    options: [{ value: '', title: '' }],
    min_value: 1,
    max_value: 10,
    max_length: null,
    url: '',
    default_value: '',
    keyboard_type: 'default',
    text_content_type: '',
    // Input field options (Apple MSP API)
    regex: '',
    input_type: 'singleline',
    label_text: '',
    prefix_text: '',
    maximum_character_count: null,
    hint_text: '',
    // DatePicker options
    date_format: 'MM/dd/yyyy',
    start_date: '',
    maximum_date: '',
    minimum_date: '',
    // Picker options
    picker_title: '',
    selected_item_index: 0,
    // Select options
    multiple_selection: false,
  };
};

const initializeForm = () => {
  formData.value = {
    title: '',
    description: '',
    pages: [],
    receivedMessage: {
      title: '',
      subtitle: '',
      imageIdentifier: '',
      style: 'large',
    },
    replyMessage: {
      title: '',
      subtitle: '',
      imageIdentifier: '',
      style: 'large',
    },
  };
  currentPageIndex.value = 0;
  activeTab.value = 'builder';
  selectedTemplate.value = null;
};

const addNewPage = () => {
  const pageNumber = formData.value.pages.length + 1;
  const newPage = {
    page_id: `page_${pageNumber}`,
    title: `${t('APPLE_FORM.PAGE_LABEL')} ${pageNumber}`,
    description: '',
    items: [],
  };

  formData.value.pages.push(newPage);
  currentPageIndex.value = formData.value.pages.length - 1;
};

const removePage = index => {
  if (formData.value.pages.length > 1) {
    formData.value.pages.splice(index, 1);
    if (currentPageIndex.value >= formData.value.pages.length) {
      currentPageIndex.value = formData.value.pages.length - 1;
    }
  }
};

const openAddFieldModal = () => {
  resetNewField();
  showAddFieldModal.value = true;
};

const addFieldToCurrentPage = () => {
  if (!currentPage.value) return;

  const isEditing = typeof newField.value.editingIndex === 'number';

  if (!newField.value.item_id && !isEditing) {
    const fieldCount = currentPage.value.items.length;
    newField.value.item_id = `field_${currentPageIndex.value + 1}_${fieldCount + 1}`;
  }

  const fieldData = { ...newField.value };

  // Remove editingIndex from saved data
  delete fieldData.editingIndex;

  if (!['singleSelect', 'multiSelect'].includes(fieldData.item_type)) {
    delete fieldData.options;
  }

  if (fieldData.item_type !== 'stepper') {
    delete fieldData.min_value;
    delete fieldData.max_value;
  }

  if (!['text', 'textArea', 'email', 'phone'].includes(fieldData.item_type)) {
    delete fieldData.max_length;
    delete fieldData.keyboard_type;
    delete fieldData.text_content_type;
  }

  if (fieldData.item_type !== 'richLink') {
    delete fieldData.url;
  }

  if (!fieldData.keyboard_type || fieldData.keyboard_type === 'default') {
    delete fieldData.keyboard_type;
  }
  if (!fieldData.text_content_type) {
    delete fieldData.text_content_type;
  }

  if (fieldData.options) {
    fieldData.options = fieldData.options.filter(opt => opt.value && opt.title);
  }

  if (isEditing) {
    // Update existing field
    currentPage.value.items[newField.value.editingIndex] = fieldData;
  } else {
    // Add new field
    currentPage.value.items.push(fieldData);
  }

  showAddFieldModal.value = false;
  resetNewField();
};

const removeField = fieldIndex => {
  if (currentPage.value && currentPage.value.items) {
    currentPage.value.items.splice(fieldIndex, 1);
  }
};

const editField = fieldIndex => {
  if (currentPage.value && currentPage.value.items) {
    const field = currentPage.value.items[fieldIndex];
    newField.value = { ...field };

    // Ensure options array exists for select fields
    if (!newField.value.options || newField.value.options.length === 0) {
      newField.value.options = [{ value: '', title: '' }];
    }

    // Store the index so we know we're editing
    newField.value.editingIndex = fieldIndex;
    showAddFieldModal.value = true;
  }
};

const addOption = () => {
  newField.value.options.push({ value: '', title: '' });
};

const removeOption = index => {
  if (newField.value.options.length > 1) {
    newField.value.options.splice(index, 1);
  }
};

const loadTemplate = templateId => {
  switch (templateId) {
    case 'contact':
      formData.value = {
        title: t('APPLE_FORM.TEMPLATES.CONTACT.FORM_TITLE'),
        description: t('APPLE_FORM.TEMPLATES.CONTACT.FORM_DESC'),
        pages: [
          {
            page_id: 'page_1',
            title: t('APPLE_FORM.TEMPLATES.CONTACT.PAGE_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.CONTACT.PAGE_DESC'),
            items: [
              {
                item_id: 'full_name',
                item_type: 'text',
                title: t('APPLE_FORM.TEMPLATES.CONTACT.FIELD_FULL_NAME'),
                required: true,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.CONTACT.PLACEHOLDER_FULL_NAME'
                ),
                keyboard_type: 'default',
                text_content_type: 'name',
              },
              {
                item_id: 'email',
                item_type: 'email',
                title: t('APPLE_FORM.TEMPLATES.CONTACT.FIELD_EMAIL'),
                required: true,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.CONTACT.PLACEHOLDER_EMAIL'
                ),
                keyboard_type: 'emailAddress',
                text_content_type: 'emailAddress',
              },
              {
                item_id: 'phone',
                item_type: 'phone',
                title: t('APPLE_FORM.TEMPLATES.CONTACT.FIELD_PHONE'),
                required: false,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.CONTACT.PLACEHOLDER_PHONE'
                ),
                keyboard_type: 'phonePad',
                text_content_type: 'telephoneNumber',
              },
            ],
          },
        ],
        receivedMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
        replyMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
      };
      break;
    case 'feedback':
      formData.value = {
        title: t('APPLE_FORM.TEMPLATES.FEEDBACK.FORM_TITLE'),
        description: t('APPLE_FORM.TEMPLATES.FEEDBACK.FORM_DESC'),
        pages: [
          {
            page_id: 'page_1',
            title: t('APPLE_FORM.TEMPLATES.FEEDBACK.PAGE_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.FEEDBACK.PAGE_DESC'),
            items: [
              {
                item_id: 'rating',
                item_type: 'stepper',
                title: t('APPLE_FORM.TEMPLATES.FEEDBACK.FIELD_RATING'),
                required: true,
                min_value: 1,
                max_value: 5,
              },
              {
                item_id: 'comments',
                item_type: 'textArea',
                title: t('APPLE_FORM.TEMPLATES.FEEDBACK.FIELD_COMMENTS'),
                required: false,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.FEEDBACK.PLACEHOLDER_COMMENTS'
                ),
              },
              {
                item_id: 'recommend',
                item_type: 'toggle',
                title: t('APPLE_FORM.TEMPLATES.FEEDBACK.FIELD_RECOMMEND'),
                required: false,
                description: t('APPLE_FORM.TEMPLATES.FEEDBACK.DESC_RECOMMEND'),
              },
            ],
          },
        ],
        receivedMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
        replyMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
      };
      break;
    case 'appointment':
      formData.value = {
        title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FORM_TITLE'),
        description: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FORM_DESC'),
        pages: [
          {
            page_id: 'page_1',
            title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.PAGE_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.APPOINTMENT.PAGE_DESC'),
            items: [
              {
                item_id: 'name',
                item_type: 'text',
                title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FIELD_NAME'),
                required: true,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.APPOINTMENT.PLACEHOLDER_NAME'
                ),
                keyboard_type: 'default',
                text_content_type: 'name',
              },
              {
                item_id: 'date',
                item_type: 'dateTime',
                title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FIELD_DATE'),
                required: true,
              },
              {
                item_id: 'service',
                item_type: 'singleSelect',
                title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FIELD_SERVICE'),
                required: true,
                options: [
                  {
                    value: 'consultation',
                    title: t(
                      'APPLE_FORM.TEMPLATES.APPOINTMENT.OPTION_CONSULTATION'
                    ),
                  },
                  {
                    value: 'meeting',
                    title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.OPTION_MEETING'),
                  },
                  {
                    value: 'demo',
                    title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.OPTION_DEMO'),
                  },
                ],
              },
              {
                item_id: 'notes',
                item_type: 'textArea',
                title: t('APPLE_FORM.TEMPLATES.APPOINTMENT.FIELD_NOTES'),
                required: false,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.APPOINTMENT.PLACEHOLDER_NOTES'
                ),
              },
            ],
          },
        ],
        receivedMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
        replyMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
      };
      break;
    case 'survey':
      formData.value = {
        title: t('APPLE_FORM.TEMPLATES.SURVEY.FORM_TITLE'),
        description: t('APPLE_FORM.TEMPLATES.SURVEY.FORM_DESC'),
        pages: [
          {
            page_id: 'page_1',
            title: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE1_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE1_DESC'),
            items: [
              {
                item_id: 'age_group',
                item_type: 'singleSelect',
                title: t('APPLE_FORM.TEMPLATES.SURVEY.FIELD_AGE_GROUP'),
                required: false,
                options: [
                  {
                    value: '18-24',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_18_24'),
                  },
                  {
                    value: '25-34',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_25_34'),
                  },
                  {
                    value: '35-44',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_35_44'),
                  },
                  {
                    value: '45+',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_45_PLUS'),
                  },
                ],
              },
            ],
          },
          {
            page_id: 'page_2',
            title: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE2_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE2_DESC'),
            items: [
              {
                item_id: 'preferences',
                item_type: 'multiSelect',
                title: t('APPLE_FORM.TEMPLATES.SURVEY.FIELD_PREFERENCES'),
                required: false,
                options: [
                  {
                    value: 'quality',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_QUALITY'),
                  },
                  {
                    value: 'price',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_PRICE'),
                  },
                  {
                    value: 'support',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_SUPPORT'),
                  },
                  {
                    value: 'features',
                    title: t('APPLE_FORM.TEMPLATES.SURVEY.OPTION_FEATURES'),
                  },
                ],
              },
            ],
          },
          {
            page_id: 'page_3',
            title: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE3_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.SURVEY.PAGE3_DESC'),
            items: [
              {
                item_id: 'satisfaction',
                item_type: 'stepper',
                title: t('APPLE_FORM.TEMPLATES.SURVEY.FIELD_SATISFACTION'),
                required: true,
                min_value: 1,
                max_value: 10,
              },
            ],
          },
        ],
        receivedMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
        replyMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
      };
      break;
    case 'order':
      formData.value = {
        title: t('APPLE_FORM.TEMPLATES.ORDER.FORM_TITLE'),
        description: t('APPLE_FORM.TEMPLATES.ORDER.FORM_DESC'),
        pages: [
          {
            page_id: 'page_1',
            title: t('APPLE_FORM.TEMPLATES.ORDER.PAGE1_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.ORDER.PAGE1_DESC'),
            items: [
              {
                item_id: 'product',
                item_type: 'singleSelect',
                title: t('APPLE_FORM.TEMPLATES.ORDER.FIELD_PRODUCT'),
                required: true,
                options: [
                  {
                    value: 'basic',
                    title: t('APPLE_FORM.TEMPLATES.ORDER.OPTION_BASIC'),
                  },
                  {
                    value: 'pro',
                    title: t('APPLE_FORM.TEMPLATES.ORDER.OPTION_PRO'),
                  },
                  {
                    value: 'enterprise',
                    title: t('APPLE_FORM.TEMPLATES.ORDER.OPTION_ENTERPRISE'),
                  },
                ],
              },
              {
                item_id: 'quantity',
                item_type: 'stepper',
                title: t('APPLE_FORM.TEMPLATES.ORDER.FIELD_QUANTITY'),
                required: true,
                min_value: 1,
                max_value: 100,
              },
            ],
          },
          {
            page_id: 'page_2',
            title: t('APPLE_FORM.TEMPLATES.ORDER.PAGE2_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.ORDER.PAGE2_DESC'),
            items: [
              {
                item_id: 'billing_name',
                item_type: 'text',
                title: t('APPLE_FORM.TEMPLATES.ORDER.FIELD_BILLING_NAME'),
                required: true,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.ORDER.PLACEHOLDER_BILLING_NAME'
                ),
                keyboard_type: 'default',
                text_content_type: 'name',
              },
              {
                item_id: 'billing_email',
                item_type: 'email',
                title: t('APPLE_FORM.TEMPLATES.ORDER.FIELD_BILLING_EMAIL'),
                required: true,
                placeholder: t(
                  'APPLE_FORM.TEMPLATES.ORDER.PLACEHOLDER_BILLING_EMAIL'
                ),
                keyboard_type: 'emailAddress',
                text_content_type: 'emailAddress',
              },
            ],
          },
          {
            page_id: 'page_3',
            title: t('APPLE_FORM.TEMPLATES.ORDER.PAGE3_TITLE'),
            description: t('APPLE_FORM.TEMPLATES.ORDER.PAGE3_DESC'),
            items: [
              {
                item_id: 'terms',
                item_type: 'toggle',
                title: t('APPLE_FORM.TEMPLATES.ORDER.FIELD_TERMS'),
                required: true,
                description: t('APPLE_FORM.TEMPLATES.ORDER.DESC_TERMS'),
              },
            ],
          },
        ],
        receivedMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
        replyMessage: {
          title: '',
          subtitle: '',
          imageIdentifier: '',
          style: 'large',
        },
      };
      break;
    default:
      // Keep empty or handle other templates
      break;
  }

  currentPageIndex.value = 0;
  activeTab.value = 'builder';
};

const createForm = () => {
  if (!canCreateForm.value) return;

  // Collect images that are actually being used
  const usedImageIdentifiers = [
    formData.value.receivedMessage.imageIdentifier,
    formData.value.replyMessage.imageIdentifier,
  ].filter(Boolean);

  const usedImages = props.availableImages.filter(
    img => usedImageIdentifiers.includes(img.identifier) && img.data
  );

  const formConfig = {
    title: formData.value.title,
    description: formData.value.description || '',
    pages: formData.value.pages,
    received_message: {
      title: formData.value.receivedMessage.title || formData.value.title,
      subtitle: formData.value.receivedMessage.subtitle,
      image_identifier: formData.value.receivedMessage.imageIdentifier,
      style: formData.value.receivedMessage.style,
    },
    reply_message: {
      title: formData.value.replyMessage.title,
      subtitle: formData.value.replyMessage.subtitle,
      image_identifier: formData.value.replyMessage.imageIdentifier,
      style: formData.value.replyMessage.style,
    },
    images: usedImages.map(img => ({
      identifier: img.identifier,
      data: img.data,
      description: img.description || img.originalName || img.identifier,
      originalName: img.originalName || img.identifier,
    })),
  };

  emit('create', {
    content_type: 'apple_form',
    content_attributes: formConfig,
  });

  emit('close');
  initializeForm();
};

const closeModal = () => {
  emit('close');
  initializeForm();
};

const saveAsTemplate = () => {
  if (!canCreateForm.value) return;

  // Collect images that are actually being used
  const usedImageIdentifiers = [
    formData.value.receivedMessage.imageIdentifier,
    formData.value.replyMessage.imageIdentifier,
  ].filter(Boolean);

  const usedImages = props.availableImages.filter(
    img => usedImageIdentifiers.includes(img.identifier) && img.data
  );

  const formConfig = {
    title: formData.value.title,
    description: formData.value.description || '',
    pages: formData.value.pages,
    received_message: {
      title: formData.value.receivedMessage.title || formData.value.title,
      subtitle: formData.value.receivedMessage.subtitle,
      image_identifier: formData.value.receivedMessage.imageIdentifier,
      style: formData.value.receivedMessage.style,
    },
    reply_message: {
      title: formData.value.replyMessage.title,
      subtitle: formData.value.replyMessage.subtitle,
      image_identifier: formData.value.replyMessage.imageIdentifier,
      style: formData.value.replyMessage.style,
    },
    images: usedImages.map(img => ({
      identifier: img.identifier,
      data: img.data,
      description: img.description || img.originalName || img.identifier,
      originalName: img.originalName || img.identifier,
    })),
  };

  emit('saveAsTemplate', {
    messageType: 'form',
    messageData: formConfig,
  });
};

watch(
  () => props.show,
  newShow => {
    if (newShow) {
      nextTick(() => {
        if (formData.value.pages.length === 0) {
          addNewPage();
        }
      });
    }
  }
);
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template -->
  <div>
    <div
      v-if="show"
      class="fixed inset-0 z-50 overflow-y-auto bg-black bg-opacity-80 flex items-center justify-center p-4"
    >
      <div
        class="bg-n-solid-1 dark:bg-n-slate-2 rounded-lg max-w-7xl w-full max-h-full overflow-hidden flex flex-col shadow-2xl border-4 border-blue-500 dark:border-blue-400 ring-4 ring-blue-200 dark:ring-blue-800"
      >
        <div
          class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-n-slate-6"
        >
          <div>
            <h2
              class="text-xl font-semibold text-slate-900 dark:text-slate-100"
            >
              {{ t('APPLE_FORM.MODAL_TITLE') }}
            </h2>
            <p class="text-sm text-slate-600 dark:text-n-slate-11 mt-1">
              {{ t('APPLE_FORM.MODAL_SUBTITLE') }}
            </p>
          </div>
          <button
            class="text-slate-400 hover:text-slate-600 dark:hover:text-n-slate-10 transition-colors"
            @click="closeModal"
          >
            <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path
                d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
              />
            </svg>
          </button>
        </div>

        <div class="flex border-b border-slate-200 dark:border-n-slate-6">
          <button
            class="px-6 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="[
              activeTab === 'templates'
                ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                : 'border-transparent text-slate-500 dark:text-n-slate-11 hover:text-slate-700 dark:hover:text-n-slate-10',
            ]"
            @click="activeTab = 'templates'"
          >
            {{ t('APPLE_FORM.TABS.TEMPLATES') }}
          </button>
          <button
            class="px-6 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="[
              activeTab === 'builder'
                ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                : 'border-transparent text-slate-500 dark:text-n-slate-11 hover:text-slate-700 dark:hover:text-n-slate-10',
            ]"
            @click="activeTab = 'builder'"
          >
            {{ t('APPLE_FORM.TABS.BUILDER') }}
          </button>
          <button
            class="px-6 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="[
              activeTab === 'preview'
                ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                : 'border-transparent text-slate-500 dark:text-n-slate-11 hover:text-slate-700 dark:hover:text-n-slate-10',
            ]"
            @click="activeTab = 'preview'"
          >
            {{ t('APPLE_FORM.TABS.PREVIEW') }}
          </button>
        </div>

        <div class="flex-1 overflow-y-auto">
          <div v-if="activeTab === 'templates'" class="p-6">
            <h3
              class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-4"
            >
              {{ t('APPLE_FORM.CHOOSE_TEMPLATE') }}
            </h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                v-for="template in formTemplates"
                :key="template.id"
                class="text-left p-4 border-2 border-slate-200 dark:border-n-slate-6 rounded-lg hover:border-woot-500 dark:hover:border-woot-400 transition-colors"
                @click="loadTemplate(template.id)"
              >
                <div class="flex items-center space-x-3">
                  <div class="text-2xl">{{ template.icon }}</div>
                  <div>
                    <h4 class="font-medium text-slate-900 dark:text-slate-100">
                      {{ template.name }}
                    </h4>
                    <p class="text-sm text-slate-600 dark:text-n-slate-11 mt-1">
                      {{ template.description }}
                    </p>
                  </div>
                </div>
              </button>
            </div>
          </div>

          <div v-else-if="activeTab === 'builder'" class="flex h-full">
            <div
              class="w-1/2 p-6 border-r border-slate-200 dark:border-n-slate-6 overflow-y-auto"
            >
              <div class="mb-6">
                <h3
                  class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3"
                >
                  {{ t('APPLE_FORM.FORM_DETAILS') }}
                </h3>
                <div class="space-y-3">
                  <div>
                    <label
                      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                    >
                      {{ t('APPLE_FORM.FORM_TITLE_LABEL') }}
                    </label>
                    <input
                      v-model="formData.title"
                      type="text"
                      :placeholder="t('APPLE_FORM.FORM_TITLE_PLACEHOLDER')"
                      class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                    />
                  </div>
                  <div>
                    <label
                      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                    >
                      {{ t('APPLE_FORM.DESCRIPTION_LABEL') }}
                    </label>
                    <textarea
                      v-model="formData.description"
                      rows="2"
                      :placeholder="t('APPLE_FORM.DESCRIPTION_PLACEHOLDER')"
                      class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                    />
                  </div>
                </div>
              </div>

              <!-- Message Configuration -->
              <div class="mb-6">
                <h3
                  class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3"
                >
                  {{ t('APPLE_FORM.MESSAGES_TAB.MESSAGE_CONFIGURATION') }}
                </h3>

                <!-- Two-column layout: Form fields on left, Image browser on right -->
                <div class="grid grid-cols-2 gap-6">
                  <!-- Left Column: Form Configuration -->
                  <div class="space-y-3">
                    <!-- Received Message Subtitle -->
                    <div>
                      <label
                        class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                      >
                        {{
                          t(
                            'APPLE_FORM.MESSAGES_TAB.RECEIVED_MESSAGE_SUBTITLE_LABEL'
                          )
                        }}
                      </label>
                      <input
                        v-model="formData.receivedMessage.subtitle"
                        type="text"
                        :placeholder="
                          t(
                            'APPLE_FORM.MESSAGES_TAB.RECEIVED_MESSAGE_SUBTITLE_PLACEHOLDER'
                          )
                        "
                        class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                      />
                    </div>

                    <!-- Style Selection -->
                    <div>
                      <label
                        class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                      >
                        {{ t('APPLE_FORM.MESSAGES_TAB.IMAGE_STYLE') }}
                      </label>
                      <select
                        v-model="formData.receivedMessage.style"
                        class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
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

                    <!-- Reply Message Section -->
                    <div
                      class="space-y-3 pt-3 border-t border-slate-200 dark:border-n-slate-6"
                    >
                      <h4
                        class="text-xs font-semibold text-slate-700 dark:text-n-slate-10"
                      >
                        {{ t('APPLE_FORM.MESSAGES_TAB.REPLY_MESSAGE') }}
                      </h4>

                      <div>
                        <label
                          class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                        >
                          {{ t('APPLE_FORM.REPLY_MESSAGE_TITLE_LABEL') }}
                        </label>
                        <input
                          v-model="formData.replyMessage.title"
                          type="text"
                          :placeholder="
                            t('APPLE_FORM.REPLY_MESSAGE_TITLE_PLACEHOLDER')
                          "
                          class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                        />
                      </div>

                      <div>
                        <label
                          class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                        >
                          {{ t('APPLE_FORM.REPLY_MESSAGE_SUBTITLE_LABEL') }}
                        </label>
                        <input
                          v-model="formData.replyMessage.subtitle"
                          type="text"
                          :placeholder="
                            t('APPLE_FORM.REPLY_MESSAGE_SUBTITLE_PLACEHOLDER')
                          "
                          class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                        />
                      </div>
                    </div>
                  </div>

                  <!-- Right Column: Image Browser -->
                  <div>
                    <label
                      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-2"
                    >
                      {{ t('APPLE_FORM.MESSAGES_TAB.IMAGE_LABEL') }}
                    </label>
                    <SharedImageSelector
                      v-model="formData.receivedMessage.imageIdentifier"
                      :account-id="currentAccountId"
                      image-type="form"
                    />
                  </div>
                </div>
              </div>

              <div class="mb-6">
                <div class="flex items-center justify-between mb-3">
                  <h3
                    class="text-base font-semibold text-slate-900 dark:text-slate-100"
                  >
                    {{ t('APPLE_FORM.PAGES') }}
                  </h3>
                  <button
                    class="px-2 py-1 bg-blue-500 text-white text-xs rounded-md hover:bg-blue-600 transition-colors"
                    @click="addNewPage"
                  >
                    {{ `+ ${t('APPLE_FORM.ADD_PAGE')}` }}
                  </button>
                </div>

                <div class="space-y-2">
                  <div
                    v-for="(page, index) in formData.pages"
                    :key="page.page_id"
                    class="flex items-center justify-between p-2 rounded-lg border cursor-pointer transition-colors"
                    :class="[
                      index === currentPageIndex
                        ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20'
                        : 'border-slate-200 dark:border-n-slate-6 hover:border-slate-300',
                    ]"
                    @click="currentPageIndex = index"
                  >
                    <div class="flex-1 min-w-0">
                      <input
                        v-model="page.title"
                        class="w-full text-sm font-medium text-slate-900 dark:text-slate-100 bg-transparent border-none p-0 focus:outline-none truncate"
                        @click.stop
                      />
                      <p class="text-xs text-slate-600 dark:text-n-slate-11">
                        {{ page.items ? page.items.length : 0 }}
                        {{ t('APPLE_FORM.FIELDS_COUNT') }}
                      </p>
                    </div>
                    <button
                      v-if="formData.pages.length > 1"
                      class="text-red-500 hover:text-red-700 transition-colors ml-2 flex-shrink-0"
                      @click.stop="removePage(index)"
                    >
                      <svg
                        class="w-4 h-4"
                        fill="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
                        />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>

              <div v-if="currentPage">
                <div class="flex items-center justify-between mb-3">
                  <h4
                    class="text-sm font-semibold text-slate-900 dark:text-slate-100 truncate"
                  >
                    {{
                      t('APPLE_FORM.FIELDS_TITLE', { page: currentPage.title })
                    }}
                  </h4>
                  <button
                    class="px-2 py-1 bg-green-500 text-white text-xs rounded-md hover:bg-green-600 transition-colors whitespace-nowrap"
                    @click="openAddFieldModal"
                  >
                    {{ t('APPLE_FORM.ADD_FIELD') }}
                  </button>
                </div>

                <div class="space-y-2">
                  <div
                    v-for="(field, index) in currentPage.items"
                    :key="field.item_id"
                    class="flex items-center justify-between p-2 bg-slate-50 dark:bg-n-slate-1 rounded-lg cursor-pointer hover:bg-slate-100 dark:hover:bg-n-slate-3 transition-colors"
                    @click="editField(index)"
                  >
                    <div class="flex-1 min-w-0">
                      <div
                        class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
                      >
                        {{ field.title }}
                      </div>
                      <div
                        class="text-xs text-slate-600 dark:text-n-slate-11 truncate"
                      >
                        {{
                          fieldTypes.find(ft => ft.value === field.item_type)
                            ?.label || field.item_type
                        }}
                        <span v-if="field.required" class="text-red-500 ml-1">
                          *
                        </span>
                      </div>
                    </div>
                    <button
                      class="text-red-500 hover:text-red-700 transition-colors ml-2 flex-shrink-0"
                      @click.stop="removeField(index)"
                    >
                      <svg
                        class="w-4 h-4"
                        fill="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
                        />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div class="w-1/2 p-6 overflow-y-auto">
              <div v-if="currentPage">
                <h3
                  class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3"
                >
                  {{ t('APPLE_FORM.PAGE_CONFIG') }}
                </h3>
                <div class="space-y-3">
                  <div>
                    <label
                      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                    >
                      {{ t('APPLE_FORM.PAGE_TITLE_LABEL') }}
                    </label>
                    <input
                      v-model="currentPage.title"
                      type="text"
                      class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                    />
                  </div>
                  <div>
                    <label
                      class="block text-xs font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                    >
                      {{ t('APPLE_FORM.PAGE_DESCRIPTION_LABEL') }}
                    </label>
                    <textarea
                      v-model="currentPage.description"
                      rows="2"
                      class="w-full px-2 py-1.5 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div v-else-if="activeTab === 'preview'" class="p-6">
            <h3
              class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-4"
            >
              {{ t('APPLE_FORM.FORM_PREVIEW') }}
            </h3>
            <div v-if="formData.pages.length === 0" class="text-center py-12">
              <p class="text-slate-600 dark:text-n-slate-11">
                {{ t('APPLE_FORM.NO_PAGES_YET') }}
              </p>
            </div>
            <div v-else class="space-y-6">
              <div
                v-for="page in formData.pages"
                :key="page.page_id"
                class="border border-slate-200 dark:border-n-slate-6 rounded-lg p-6"
              >
                <div class="mb-4">
                  <h4
                    class="text-lg font-semibold text-slate-900 dark:text-slate-100"
                  >
                    {{ page.title }}
                  </h4>
                  <p
                    v-if="page.description"
                    class="text-sm text-slate-600 dark:text-n-slate-11 mt-1"
                  >
                    {{ page.description }}
                  </p>
                </div>

                <div
                  v-if="page.items && page.items.length > 0"
                  class="space-y-4"
                >
                  <div
                    v-for="field in page.items"
                    :key="field.item_id"
                    class="space-y-2"
                  >
                    <label
                      class="block text-sm font-medium text-slate-700 dark:text-n-slate-10"
                    >
                      {{ field.title }}
                      <span v-if="field.required" class="text-red-500">*</span>
                    </label>

                    <input
                      v-if="
                        ['text', 'email', 'phone'].includes(field.item_type)
                      "
                      :type="
                        field.item_type === 'email'
                          ? 'email'
                          : field.item_type === 'phone'
                            ? 'tel'
                            : 'text'
                      "
                      :placeholder="field.placeholder"
                      disabled
                      class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1 text-slate-900 dark:text-slate-100"
                    />

                    <textarea
                      v-else-if="field.item_type === 'textArea'"
                      :placeholder="field.placeholder"
                      rows="3"
                      disabled
                      class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1 text-slate-900 dark:text-slate-100"
                    />

                    <select
                      v-else-if="
                        ['singleSelect', 'multiSelect'].includes(
                          field.item_type
                        )
                      "
                      disabled
                      class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1 text-slate-900 dark:text-slate-100"
                    >
                      <option value="">
                        {{ t('APPLE_FORM.SELECT_OPTION') }}
                      </option>
                      <option
                        v-for="option in field.options"
                        :key="option.value"
                        :value="option.value"
                      >
                        {{ option.title }}
                      </option>
                    </select>

                    <div
                      v-else-if="field.item_type === 'toggle'"
                      class="flex items-center"
                    >
                      <input
                        type="checkbox"
                        disabled
                        class="rounded border-slate-300 text-woot-600 focus:ring-woot-500"
                      />
                      <span
                        class="ml-2 text-sm text-slate-600 dark:text-n-slate-11"
                      >
                        {{ field.description || t('APPLE_FORM.TOGGLE_OPTION') }}
                      </span>
                    </div>

                    <div
                      v-else-if="field.item_type === 'stepper'"
                      class="flex items-center space-x-2"
                    >
                      <button
                        type="button"
                        disabled
                        class="px-3 py-1 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1"
                      >
                        -
                      </button>
                      <input
                        type="number"
                        :value="field.min_value || 1"
                        disabled
                        class="w-20 px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1 text-center"
                      />
                      <button
                        type="button"
                        disabled
                        class="px-3 py-1 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1"
                      >
                        +
                      </button>
                    </div>

                    <input
                      v-else-if="field.item_type === 'dateTime'"
                      type="datetime-local"
                      disabled
                      class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1 text-slate-900 dark:text-slate-100"
                    />

                    <div
                      v-else-if="field.item_type === 'richLink'"
                      class="p-3 border border-slate-300 dark:border-n-slate-6 rounded-md bg-slate-50 dark:bg-n-slate-1"
                    >
                      <a
                        :href="field.url"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="text-woot-600 hover:underline"
                      >
                        {{ field.url || t('APPLE_FORM.LINK_URL') }}
                      </a>
                    </div>
                  </div>
                </div>
                <div
                  v-else
                  class="text-center py-8 text-slate-500 dark:text-n-slate-11"
                >
                  {{ t('APPLE_FORM.NO_FIELDS_YET') }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div
          class="flex items-center justify-between p-6 border-t border-slate-200 dark:border-n-slate-6"
        >
          <div class="text-sm text-slate-600 dark:text-n-slate-11">
            {{
              t('APPLE_FORM.SUMMARY', {
                pages: formData.pages.length,
                fields: totalFields,
              })
            }}
          </div>
          <div class="flex space-x-3">
            <button
              class="px-4 py-2 text-slate-600 dark:text-n-slate-11 hover:text-slate-800 dark:hover:text-n-slate-10 transition-colors"
              @click="closeModal"
            >
              {{ t('APPLE_FORM.CANCEL') }}
            </button>
            <button
              :disabled="!canCreateForm"
              class="px-4 py-2 border border-woot-500 text-woot-600 rounded-md hover:bg-woot-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              @click="saveAsTemplate"
            >
              Save as Template
            </button>
            <button
              :disabled="!canCreateForm"
              class="px-4 py-2 bg-woot-500 text-white rounded-md hover:bg-woot-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              @click="createForm"
            >
              {{ t('APPLE_FORM.CREATE_FORM') }}
            </button>
          </div>
        </div>
      </div>

      <div
        v-if="showAddFieldModal"
        class="fixed inset-0 z-60 overflow-y-auto bg-black bg-opacity-90 flex items-center justify-center p-4"
      >
        <div
          class="bg-n-solid-1 dark:bg-n-slate-2 rounded-lg max-w-2xl w-full max-h-full overflow-y-auto shadow-2xl border-4 border-green-500 dark:border-green-400"
        >
          <div class="p-6">
            <h3
              class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-4"
            >
              {{
                typeof newField.editingIndex === 'number'
                  ? 'Edit Form Field'
                  : t('APPLE_FORM.ADD_FIELD_TITLE')
              }}
            </h3>

            <div class="mb-4">
              <label
                class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-2"
              >
                {{ t('APPLE_FORM.FIELD_TYPE') }}
              </label>
              <div class="grid grid-cols-2 gap-2">
                <button
                  v-for="fieldType in fieldTypes"
                  :key="fieldType.value"
                  class="text-left p-3 border-2 rounded-lg transition-colors"
                  :class="[
                    newField.item_type === fieldType.value
                      ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20'
                      : 'border-slate-200 dark:border-n-slate-6 hover:border-slate-300',
                  ]"
                  @click="newField.item_type = fieldType.value"
                >
                  <div class="flex items-center space-x-2">
                    <span class="text-lg">{{ fieldType.icon }}</span>
                    <div>
                      <div
                        class="font-medium text-slate-900 dark:text-slate-100 text-sm"
                      >
                        {{ fieldType.label }}
                      </div>
                      <div class="text-xs text-slate-600 dark:text-n-slate-11">
                        {{ fieldType.description }}
                      </div>
                    </div>
                  </div>
                </button>
              </div>
            </div>

            <div class="space-y-4">
              <div>
                <label
                  class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                >
                  {{ t('APPLE_FORM.FIELD_TITLE') }}
                </label>
                <input
                  v-model="newField.title"
                  type="text"
                  :placeholder="t('APPLE_FORM.FIELD_TITLE_PLACEHOLDER')"
                  class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                />
              </div>

              <div>
                <label
                  class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                >
                  {{ t('APPLE_FORM.DESCRIPTION_LABEL') }}
                </label>
                <input
                  v-model="newField.description"
                  type="text"
                  :placeholder="t('APPLE_FORM.FIELD_DESCRIPTION_PLACEHOLDER')"
                  class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                />
              </div>

              <div class="flex items-center space-x-2">
                <input
                  v-model="newField.required"
                  type="checkbox"
                  class="rounded border-slate-300 text-woot-600 focus:ring-woot-500"
                />
                <label class="text-sm text-slate-700 dark:text-n-slate-10">
                  {{ t('APPLE_FORM.REQUIRED_FIELD') }}
                </label>
              </div>

              <!-- Input Field Options (text, textArea, email, phone) -->
              <div
                v-if="
                  ['text', 'textArea', 'email', 'phone'].includes(
                    newField.item_type
                  )
                "
                class="space-y-4"
              >
                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('APPLE_FORM.PLACEHOLDER') }}
                  </label>
                  <input
                    v-model="newField.placeholder"
                    type="text"
                    :placeholder="t('APPLE_FORM.PLACEHOLDER_TEXT')"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('APPLE_FORM.FIELD_OPTIONS.LABEL_TEXT') }}
                  </label>
                  <input
                    v-model="newField.label_text"
                    type="text"
                    :placeholder="
                      t('APPLE_FORM.FIELD_OPTIONS.LABEL_TEXT_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.PREFIX_TEXT_LABEL') }}
                  </label>
                  <input
                    v-model="newField.prefix_text"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.PREFIX_TEXT_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.HINT_TEXT_LABEL') }}
                  </label>
                  <input
                    v-model="newField.hint_text"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.HINT_TEXT_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.MAX_CHAR_COUNT') }}
                  </label>
                  <input
                    v-model.number="newField.maximum_character_count"
                    type="number"
                    :placeholder="
                      t(
                        'TEMPLATES.BUILDER.APPLE_FORM.MAX_CHAR_COUNT_PLACEHOLDER'
                      )
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.INPUT_TYPE_LABEL') }}
                  </label>
                  <select
                    v-model="newField.input_type"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  >
                    <option value="singleline">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.INPUT_TYPE_SINGLELINE')
                      }}
                    </option>
                    <option value="multiline">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.INPUT_TYPE_MULTILINE')
                      }}
                    </option>
                  </select>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_LABEL') }}
                  </label>
                  <select
                    v-model="newField.keyboard_type"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  >
                    <option value="default">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_DEFAULT')
                      }}
                    </option>
                    <option value="asciiCapable">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_ASCII')
                      }}
                    </option>
                    <option value="numbersAndPunctuation">
                      Numbers & Punctuation
                    </option>
                    <option value="URL">
                      {{ t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_URL') }}
                    </option>
                    <option value="numberPad">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_NUMBER_PAD'
                        )
                      }}
                    </option>
                    <option value="phonePad">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_PHONE_PAD'
                        )
                      }}
                    </option>
                    <option value="namePhonePad">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_NAME_PHONE'
                        )
                      }}
                    </option>
                    <option value="emailAddress">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_EMAIL')
                      }}
                    </option>
                    <option value="decimalPad">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_DECIMAL')
                      }}
                    </option>
                    <option value="UIKeyboardTypeTwitter">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_TWITTER')
                      }}
                    </option>
                    <option value="webSearch">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_WEB_SEARCH'
                        )
                      }}
                    </option>
                  </select>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{
                      t('TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_LABEL')
                    }}
                  </label>
                  <select
                    v-model="newField.text_content_type"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  >
                    <option value="">
                      {{ t('TEMPLATES.BUILDER.APPLE_FORM.IMAGE_NONE_OPTION') }}
                    </option>
                    <option value="name">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_NAME')
                      }}
                    </option>
                    <option value="namePrefix">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_NAME_PREFIX'
                        )
                      }}
                    </option>
                    <option value="givenName">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_GIVEN_NAME'
                        )
                      }}
                    </option>
                    <option value="middleName">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_MIDDLE_NAME'
                        )
                      }}
                    </option>
                    <option value="familyName">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_FAMILY_NAME'
                        )
                      }}
                    </option>
                    <option value="nameSuffix">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_NAME_SUFFIX'
                        )
                      }}
                    </option>
                    <option value="nickname">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_NICKNAME'
                        )
                      }}
                    </option>
                    <option value="jobTitle">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_JOB_TITLE'
                        )
                      }}
                    </option>
                    <option value="organizationName">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_ORG_NAME'
                        )
                      }}
                    </option>
                    <option value="location">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_LOCATION'
                        )
                      }}
                    </option>
                    <option value="fullStreetAddress">
                      Full Street Address
                    </option>
                    <option value="streetAddressLine1">
                      Street Address Line 1
                    </option>
                    <option value="streetAddressLine2">
                      Street Address Line 2
                    </option>
                    <option value="addressCity">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_CITY')
                      }}
                    </option>
                    <option value="addressState">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_STATE'
                        )
                      }}
                    </option>
                    <option value="addressCityAndState">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_CITY_STATE'
                        )
                      }}
                    </option>
                    <option value="sublocality">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_SUBLOCALITY'
                        )
                      }}
                    </option>
                    <option value="countryName">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_COUNTRY'
                        )
                      }}
                    </option>
                    <option value="postalCode">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_POSTAL_CODE'
                        )
                      }}
                    </option>
                    <option value="telephoneNumber">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_PHONE'
                        )
                      }}
                    </option>
                    <option value="emailAddress">
                      {{
                        t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_EMAIL')
                      }}
                    </option>
                    <option value="URL">
                      {{ t('TEMPLATES.BUILDER.APPLE_FORM.KEYBOARD_TYPE_URL') }}
                    </option>
                    <option value="creditCardNumber">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_CREDIT_CARD'
                        )
                      }}
                    </option>
                    <option value="username">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_USERNAME'
                        )
                      }}
                    </option>
                    <option value="password">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_PASSWORD'
                        )
                      }}
                    </option>
                    <option value="newPassword">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_NEW_PASSWORD'
                        )
                      }}
                    </option>
                    <option value="oneTimeCode">
                      {{
                        t(
                          'TEMPLATES.BUILDER.APPLE_FORM.TEXT_CONTENT_TYPE_ONE_TIME_CODE'
                        )
                      }}
                    </option>
                  </select>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Regex Pattern (JSON encoded)
                  </label>
                  <input
                    v-model="newField.regex"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.REGEX_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white font-mono text-sm"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    JSON encode all regex strings. Used to limit input type.
                  </p>
                </div>
              </div>

              <!-- DatePicker Options -->
              <div v-if="newField.item_type === 'dateTime'" class="space-y-4">
                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Label Text
                  </label>
                  <input
                    v-model="newField.label_text"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.DATE_LABEL_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    {{ t('TEMPLATES.BUILDER.APPLE_FORM.HINT_TEXT_LABEL') }}
                  </label>
                  <input
                    v-model="newField.hint_text"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.DATE_HINT_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Date Format
                  </label>
                  <input
                    v-model="newField.date_format"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.DATE_FORMAT_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    Default: MM/dd/yyyy
                  </p>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Start Date
                  </label>
                  <input
                    v-model="newField.start_date"
                    type="date"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    Initial date displayed (defaults to current date)
                  </p>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Minimum Date
                  </label>
                  <input
                    v-model="newField.minimum_date"
                    type="date"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Maximum Date
                  </label>
                  <input
                    v-model="newField.maximum_date"
                    type="date"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    Defaults to current date
                  </p>
                </div>
              </div>

              <!-- Picker Options -->
              <div v-if="newField.item_type === 'picker'" class="space-y-4">
                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Picker Title
                  </label>
                  <input
                    v-model="newField.picker_title"
                    type="text"
                    :placeholder="
                      t('TEMPLATES.BUILDER.APPLE_FORM.PICKER_TITLE_PLACEHOLDER')
                    "
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    When empty, picker centers on page
                  </p>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-1"
                  >
                    Selected Item Index
                  </label>
                  <input
                    v-model.number="newField.selected_item_index"
                    type="number"
                    min="0"
                    placeholder="0"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                  />
                  <p class="mt-1 text-xs text-slate-500 dark:text-n-slate-11">
                    Zero-indexed default selected item (defaults to 0)
                  </p>
                </div>
              </div>

              <!-- Select Options (singleSelect, multiSelect) -->

              <div
                v-if="
                  ['singleSelect', 'multiSelect'].includes(newField.item_type)
                "
                class="space-y-4"
              >
                <div
                  v-if="newField.item_type === 'singleSelect'"
                  class="flex items-center space-x-2"
                >
                  <input
                    v-model="newField.multiple_selection"
                    type="checkbox"
                    class="rounded border-slate-300 text-woot-600 focus:ring-woot-500"
                  />
                  <label class="text-sm text-slate-700 dark:text-n-slate-10">
                    {{
                      t(
                        'TEMPLATES.BUILDER.APPLE_FORM.ENABLE_MULTIPLE_SELECTION'
                      )
                    }}
                  </label>
                </div>

                <div>
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-n-slate-10 mb-2"
                  >
                    {{ t('APPLE_FORM.OPTIONS') }}
                  </label>
                  <div class="space-y-2">
                    <div
                      v-for="(option, index) in newField.options"
                      :key="index"
                      class="space-y-2"
                    >
                      <div class="flex items-center space-x-2">
                        <input
                          v-model="option.value"
                          type="text"
                          :placeholder="t('APPLE_FORM.OPTION_VALUE')"
                          class="flex-1 px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                        />
                        <input
                          v-model="option.title"
                          type="text"
                          :placeholder="t('APPLE_FORM.OPTION_LABEL')"
                          class="flex-1 px-3 py-2 border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                        />
                        <button
                          class="text-red-500 hover:text-red-700 transition-colors"
                          @click="removeOption(index)"
                        >
                          <svg
                            class="w-4 h-4"
                            fill="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              d="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
                            />
                          </svg>
                        </button>
                      </div>

                      <!-- Image selector for option -->
                      <div class="ml-4 flex items-center space-x-2">
                        <label
                          class="text-xs text-slate-600 dark:text-n-slate-11"
                        >
                          {{
                            t('TEMPLATES.BUILDER.APPLE_FORM.OPTION_IMAGE_LABEL')
                          }}
                        </label>
                        <select
                          v-model="option.imageIdentifier"
                          class="flex-1 px-2 py-1 text-sm border border-slate-300 dark:border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-woot-500 dark:bg-n-slate-1 dark:text-white"
                        >
                          <option value="">
                            {{
                              t(
                                'TEMPLATES.BUILDER.APPLE_FORM.IMAGE_NONE_OPTION'
                              )
                            }}
                          </option>
                          <option
                            v-for="img in availableImages"
                            :key="img.identifier"
                            :value="img.identifier"
                          >
                            {{ img.identifier }}
                          </option>
                        </select>
                        <div
                          v-if="
                            option.imageIdentifier &&
                            getImagePreviewUrl(option.imageIdentifier)
                          "
                          class="w-8 h-8 rounded overflow-hidden border border-slate-300 dark:border-n-slate-6"
                        >
                          <img
                            :src="getImagePreviewUrl(option.imageIdentifier)"
                            alt="Option image"
                            class="w-full h-full object-cover"
                          />
                        </div>
                      </div>
                    </div>
                    <button
                      class="w-full py-2 border-2 border-dashed border-slate-300 dark:border-n-slate-6 rounded-md text-slate-600 dark:text-n-slate-11 hover:border-slate-400 dark:hover:border-slate-500 transition-colors"
                      @click="addOption"
                    >
                      {{ t('APPLE_FORM.ADD_OPTION') }}
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex justify-end space-x-3 mt-6">
              <button
                class="px-4 py-2 text-slate-600 dark:text-n-slate-11 hover:text-slate-800 dark:hover:text-n-slate-10 transition-colors"
                @click="showAddFieldModal = false"
              >
                {{ t('APPLE_FORM.CANCEL') }}
              </button>
              <button
                :disabled="!newField.title"
                class="px-4 py-2 bg-woot-500 text-white rounded-md hover:bg-woot-600 transition-colors disabled:opacity-50"
                @click="addFieldToCurrentPage"
              >
                {{ t('APPLE_FORM.ADD_FIELD') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
