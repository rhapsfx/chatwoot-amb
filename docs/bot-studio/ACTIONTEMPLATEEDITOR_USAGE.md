# ActionTemplateEditor Component

## Overview

The `ActionTemplateEditor` component provides a comprehensive UI for creating and editing Bot Action Templates in the Bot Studio. Users can select from 12 template types, configure parameters, and save templates for reuse across bot flows.

## Component Location

```
app/javascript/dashboard/routes/dashboard/settings/agentBots/components/ActionTemplateEditor.vue
```

## Features

- **Dialog-based UI**: Full-screen modal with 7xl width
- **12 Template Types**: Grid-based selection with icons and descriptions
- **Dynamic Parameter Editors**: Load specific editor components based on template type
- **Preview Panel**: Real-time preview of template configuration
- **Edit Mode**: Support for editing existing templates
- **Validation**: Form validation with disabled save button when invalid
- **I18n Support**: All strings are internationalized

## Template Types

The component supports 12 template types:

1. **send_text_message** - Send text message (i-lucide-message-square)
2. **send_list_picker** - Send list picker (i-lucide-list)
3. **send_time_picker** - Send time picker (i-lucide-clock)
4. **send_form** - Send form (i-lucide-file-text)
5. **send_rich_link** - Send rich link (i-lucide-link)
6. **send_quick_reply** - Send quick reply (i-lucide-message-circle)
7. **update_attributes** - Update attributes (i-lucide-database)
8. **conditional_branch** - Conditional branch (i-lucide-git-branch)
9. **send_apple_pay** - Send Apple Pay (i-lucide-credit-card)
10. **api_call** - API call (i-lucide-globe)
11. **send_imessage_app** - Send iMessage app (i-lucide-smartphone)
12. **send_app_clip** - Send App Clip (i-lucide-app-window)

## Usage

### Basic Usage

```vue
<script setup>
import { ref } from 'vue';
import ActionTemplateEditor from './ActionTemplateEditor.vue';

const editorRef = ref(null);
const accountId = 123;

const openEditor = () => {
  editorRef.value?.open();
};

const handleSave = (templateData) => {
  console.log('Template saved:', templateData);
  // Save to backend via API
};

const handleClose = () => {
  console.log('Editor closed');
};
</script>

<template>
  <div>
    <button @click="openEditor">Create Template</button>

    <ActionTemplateEditor
      ref="editorRef"
      :account-id="accountId"
      @save="handleSave"
      @close="handleClose"
    />
  </div>
</template>
```

### Edit Mode

```vue
<script setup>
import { ref } from 'vue';
import ActionTemplateEditor from './ActionTemplateEditor.vue';

const editorRef = ref(null);
const accountId = 123;

const existingTemplate = {
  name: 'Welcome Message',
  template_type: 'send_text_message',
  parameters: {
    text: 'Welcome to our service!',
  },
};

const openEditor = () => {
  editorRef.value?.open();
};

const handleSave = (templateData) => {
  console.log('Template updated:', templateData);
  // Update via API
};
</script>

<template>
  <div>
    <button @click="openEditor">Edit Template</button>

    <ActionTemplateEditor
      ref="editorRef"
      :account-id="accountId"
      :template="existingTemplate"
      @save="handleSave"
      @close="handleClose"
    />
  </div>
</template>
```

## Props

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `accountId` | Number | Yes | - | Current account ID |
| `template` | Object | No | `null` | Existing template for edit mode |

### Template Object Structure

```javascript
{
  name: 'Template Name',
  template_type: 'send_text_message', // One of 12 types
  parameters: {
    // Type-specific parameters
  }
}
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `save` | `templateData` | Emitted when user saves template |
| `close` | - | Emitted when dialog closes |

### Save Event Payload

```javascript
{
  name: 'Welcome Message',
  template_type: 'send_text_message',
  parameters: {
    text: 'Welcome!',
    // ... other parameters based on type
  }
}
```

## Exposed Methods

| Method | Description |
|--------|-------------|
| `open()` | Opens the dialog |
| `close()` | Closes the dialog and resets form |

## Component Structure

```
ActionTemplateEditor.vue
├── Dialog (7xl width)
│   ├── Template Name Input
│   ├── Template Type Selector (3-column grid)
│   ├── Parameter Editor (dynamic component)
│   │   └── Component based on selected type
│   ├── Preview Panel
│   └── Footer Actions (Cancel/Save)
```

## Dynamic Editor Components

The component uses lazy-loaded editor components based on template type:

```javascript
// Located in: editors/templates/
SendTextMessageTemplate.vue
SendListPickerTemplate.vue
SendTimePickerTemplate.vue
SendFormTemplate.vue
SendRichLinkTemplate.vue
SendQuickReplyTemplate.vue
UpdateAttributesTemplate.vue
ConditionalBranchTemplate.vue
SendApplePayTemplate.vue
ApiCallTemplate.vue
SendIMessageAppTemplate.vue
SendAppClipTemplate.vue
```

### Editor Component Interface

Each editor component must implement:

```vue
<script setup>
const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
  },
  accountId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['update:modelValue']);

// Use v-model pattern
const updateParameters = (newParams) => {
  emit('update:modelValue', newParams);
};
</script>
```

## Graceful Degradation

If an editor component doesn't exist yet, the component shows a fallback message:

```
🚧 Editor Coming Soon
[Template Type Name]
```

This allows the main component to be deployed before all 12 editor components are complete.

## Styling

- Uses **Tailwind CSS only** (no custom CSS)
- Responsive grid: 1 column (mobile) → 2 columns (md) → 3 columns (lg)
- Consistent color system:
  - Primary: `n-blue-8`
  - Text: `n-slate-12`, `n-slate-11`
  - Borders: `n-weak`, `n-strong`
  - Background: `n-white`, `n-slate-1`

## I18n Keys Required

All I18n keys will be added in Task 1.5. The component uses the following key structure:

```
AGENT_BOTS.TEMPLATES.ACTION_TEMPLATES:
  - CREATE_TITLE
  - EDIT_TITLE
  - NAME
  - NAME_PLACEHOLDER
  - SELECT_TYPE
  - PARAMETERS
  - PREVIEW
  - TYPE
  - ACTION
  - CREATE
  - EDITOR_COMING_SOON

  TYPES:
    SEND_TEXT_MESSAGE:
      - NAME
      - DESCRIPTION
    SEND_LIST_PICKER:
      - NAME
      - DESCRIPTION
    ... (and so on for all 12 types)
```

## Validation

The save button is disabled when:
- Template name is empty
- No template type is selected

Additional validation may be added by individual editor components.

## State Management

- **Local state**: Managed via Vue 3 Composition API refs
- **Form reset**: Automatic on close
- **Type change**: Parameters reset when type changes
- **Edit mode**: Form populated from `template` prop

## Integration Points

1. **BotStudio.vue**: Parent component that manages templates
2. **Backend API**: POST/PUT `/api/v1/accounts/:account_id/agent_bots/:bot_id/bot_action_templates`
3. **Template Browser**: List view of all templates

## Next Steps

The next task (1.3) will create the individual editor components for each template type, starting with the most commonly used ones.

## File References

- Component: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/ActionTemplateEditor.vue`
- Editor Directory: `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/editors/templates/`
- Related: `docs/bot-studio/TEMPLATE_BASED_HANDLER_SYSTEM_PLAN.md` (architecture docs)
