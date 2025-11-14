# Quick Integration Guide: Adding Image Validation to Template UI

## Option 1: Add to Template List Page (Index.vue)

Add validation button to each template card:

```vue
<script setup>
import ImageValidationModal from './components/ImageValidationModal.vue';

// Add state
const showValidationModal = ref(false);
const selectedTemplateForValidation = ref(null);

// Add method
const openValidation = (template) => {
  selectedTemplateForValidation.value = template;
  showValidationModal.value = true;
};
</script>

<template>
  <!-- In the template card actions, add: -->
  <button
    v-if="template.supportedChannels?.includes('apple_messages_for_business')"
    @click.stop="openValidation(template)"
    class="p-2 text-slate-600 hover:text-blue-600 hover:bg-blue-50 rounded"
    :title="t('TEMPLATES.IMAGE_VALIDATION.TITLE')"
  >
    <i class="icon ion-images" />
  </button>

  <!-- Add modal at end of template -->
  <ImageValidationModal
    v-if="selectedTemplateForValidation"
    :template-id="selectedTemplateForValidation.id"
    :show="showValidationModal"
    @close="showValidationModal = false"
  />
</template>
```

## Option 2: Add to Template Builder Page (TemplateBuilder.vue)

Add validation button to the toolbar:

```vue
<script setup>
import ImageValidationModal from './components/ImageValidationModal.vue';

// Add state
const showValidationModal = ref(false);

// Add method to check if template uses images
const templateUsesImages = computed(() => {
  // Check if any content block is list_picker, time_picker, or form
  return contentBlocks.value.some(block =>
    ['list_picker', 'time_picker', 'form'].includes(block.blockType)
  );
});
</script>

<template>
  <!-- In the toolbar, add: -->
  <Button
    v-if="templateUsesImages && template.id"
    variant="smooth"
    color-scheme="secondary"
    @click="showValidationModal = true"
  >
    <i class="icon ion-images mr-2" />
    {{ t('TEMPLATES.IMAGE_VALIDATION.TITLE') }}
  </Button>

  <!-- Add modal at end of template -->
  <ImageValidationModal
    v-if="template.id"
    :template-id="template.id"
    :show="showValidationModal"
    @close="showValidationModal = false"
  />
</template>
```

## Option 3: Add to Conversation Composer

Show warning when selecting template with missing images:

```vue
<script setup>
import TemplatesAPI from 'dashboard/api/templates';

// Add validation check when template selected
const checkTemplateImages = async (templateId) => {
  try {
    const { data } = await TemplatesAPI.validateImages(templateId, currentInboxId.value);
    const currentInbox = data.validationResults.find(r => r.inboxId === currentInboxId.value);

    if (currentInbox && !currentInbox.allAvailable) {
      // Show warning
      showAlert(
        t('TEMPLATES.IMAGE_VALIDATION.MISSING_IN_INBOX', {
          missing: currentInbox.missing.join(', ')
        }),
        'warning'
      );
    }
  } catch (error) {
    console.error('Image validation failed:', error);
  }
};

// Call when template selected
watch(selectedTemplateId, (newId) => {
  if (newId) {
    checkTemplateImages(newId);
  }
});
</script>
```

## Quick Test

1. **Start dev server**:
   ```bash
   ./dev-server.sh start
   ```

2. **Navigate to templates**:
   - Go to Settings → Templates
   - Find template 321 (Guitar List Picker)
   - Click new validation button (after integration)

3. **Expected behavior**:
   - Modal opens showing validation status
   - Shows which inboxes have missing images
   - Allows copying images between inboxes

## API Test (Before UI Integration)

Test the API endpoint directly:

```bash
# From terminal
curl -X GET "http://localhost:3000/api/v1/accounts/1/templates/321/validate_images" \
  -H "api_access_token: YOUR_TOKEN"

# Or from rails console
rails runner "
  template = MessageTemplate.find(321)
  controller = Api::V1::Accounts::TemplatesController.new
  controller.instance_variable_set(:@template, template)

  # Mock Current.account
  account = Account.first
  Current.account = account

  # Get validation results
  inbox_ids = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').pluck(:id)
  identifiers = template.extract_image_identifiers_from_blocks

  results = inbox_ids.map do |inbox_id|
    inbox = account.inboxes.find(inbox_id)
    available = AppleListPickerImage.where(inbox_id: inbox_id, identifier: identifiers).pluck(:identifier)
    missing = identifiers - available

    {
      inboxId: inbox_id,
      inboxName: inbox.name,
      identifiers: identifiers,
      available: available,
      missing: missing,
      allAvailable: missing.empty?
    }
  end

  puts JSON.pretty_generate(results)
"
```

## Recommended Next Steps

1. Choose integration option (recommend Option 1 for template list)
2. Test API endpoint first to verify backend works
3. Add UI integration
4. Test end-to-end with actual template
5. Add visual indicators (badges) showing compatibility

## Visual Indicator Example

Add badge to template card showing inbox compatibility:

```vue
<div v-if="template.supportedChannels?.includes('apple_messages_for_business')" class="flex items-center gap-2">
  <span class="text-xs text-slate-500">
    <i class="icon ion-images mr-1" />
    Images:
  </span>
  <span v-if="template.imageValidation?.allInboxesOk" class="text-xs text-green-600">
    <i class="icon ion-checkmark-circled" />
    ✓ All inboxes
  </span>
  <span v-else class="text-xs text-yellow-600">
    <i class="icon ion-alert-circled" />
    ! {{ template.imageValidation?.missingCount }} inbox(es)
  </span>
</div>
```

To populate `imageValidation`, call the API when loading templates:

```javascript
const fetchTemplates = async () => {
  const response = await TemplatesAPI.get();
  templates.value = response.data.templates;

  // Optionally validate images for Apple Messages templates
  for (const template of templates.value) {
    if (template.supportedChannels?.includes('apple_messages_for_business')) {
      try {
        const validation = await TemplatesAPI.validateImages(template.id);
        template.imageValidation = {
          allInboxesOk: validation.data.validationResults.every(r => r.allAvailable),
          missingCount: validation.data.validationResults.filter(r => !r.allAvailable).length
        };
      } catch (error) {
        // Ignore validation errors, optional feature
      }
    }
  }
};
```
