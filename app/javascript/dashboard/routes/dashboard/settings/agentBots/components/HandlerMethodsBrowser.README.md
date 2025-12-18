# Handler Methods Browser Component

## Overview

The `HandlerMethodsBrowser.vue` component is a modal dialog for browsing, searching, and selecting handler methods for bot flows. It provides a rich, filterable interface to explore all available handler methods with real-time search, detailed metadata preview, and intelligent grouping.

## Features

- **Real-time Search**: Debounced fuzzy search across method names, descriptions, and tags
- **Multi-filter Support**: Filter by handler type, category, and status
- **Category Grouping**: Handlers organized by category with collapsible sections
- **Sort Options**: Sort by alphabetical order, handler type, or status
- **Preview Panel**: Hover to see detailed handler metadata without leaving the list
- **Match Scoring**: Search results show relevance scores and match reasons
- **Keyboard Navigation**: Escape to close, Enter to select
- **Caching**: Intelligent caching for performance (5-minute cache duration)
- **Loading States**: Proper loading, error, and empty states

## Component API

### Props

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `botId` | Number | Yes | - | The bot ID for API requests |
| `serviceName` | String | No | `null` | Optional service name override (defaults to bot's service) |
| `handlerType` | String | No | `null` | Pre-filter by handler type: 'state', 'keyword', 'interactive', or 'action' |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `handler-selected` | Handler metadata object | Emitted when user selects a handler and clicks "Select Handler" |

### Exposed Methods

| Method | Description |
|--------|-------------|
| `open()` | Opens the browser modal |
| `close()` | Closes the browser modal |

## Usage

### Basic Usage

```vue
<script setup>
import { ref } from 'vue';
import HandlerMethodsBrowser from './HandlerMethodsBrowser.vue';

const browserRef = ref(null);
const botId = ref(1);

function handleHandlerSelected(handler) {
  console.log('Selected:', handler.method_name);
  // Use handler.method_name in your flow node
}
</script>

<template>
  <button @click="browserRef.open()">
    Browse Handlers
  </button>

  <HandlerMethodsBrowser
    ref="browserRef"
    :bot-id="botId"
    @handler-selected="handleHandlerSelected"
  />
</template>
```

### With Service Name Override

```vue
<HandlerMethodsBrowser
  ref="browserRef"
  :bot-id="botId"
  service-name="AcousticHouseBotService"
  @handler-selected="handleHandlerSelected"
/>
```

### Pre-filtered by Handler Type

```vue
<HandlerMethodsBrowser
  ref="browserRef"
  :bot-id="botId"
  handler-type="state"
  @handler-selected="handleHandlerSelected"
/>
```

### Integration with State Node Editor

```vue
<script setup>
import { ref } from 'vue';
import HandlerMethodsBrowser from './HandlerMethodsBrowser.vue';

const browserRef = ref(null);
const nodeData = ref({
  stateId: 'AHA1',
  handlerMethod: '',
});

function handleHandlerSelected(handler) {
  // Update node with selected handler
  nodeData.value.handlerMethod = handler.method_name;

  // Optional: Also update label if not set
  if (!nodeData.value.label) {
    nodeData.value.label = handler.display_name;
  }
}
</script>

<template>
  <div>
    <label>Handler Method</label>
    <div class="flex gap-2">
      <input v-model="nodeData.handlerMethod" />
      <button @click="browserRef.open()">
        Browse
      </button>
    </div>

    <HandlerMethodsBrowser
      ref="browserRef"
      :bot-id="botId"
      handler-type="state"
      @handler-selected="handleHandlerSelected"
    />
  </div>
</template>
```

## Handler Metadata Structure

When a handler is selected, the `handler-selected` event emits an object with the following structure:

```typescript
{
  method_name: string;              // e.g., "handle_welcome"
  handler_type: string;             // "state" | "keyword" | "interactive" | "action"
  display_name: string;             // Human-readable name
  description: string;              // Description of what the handler does
  category: string;                 // e.g., "onboarding", "forms", "navigation"
  status: string;                   // "stable" | "experimental" | "deprecated"
  service_name: string;             // Service class name
  triggers_count: number;           // Number of triggers defined
  dependencies_count: number;       // Number of dependencies

  // Available when hovering for preview:
  triggers?: {
    state_ids?: string[];           // State IDs that trigger this handler
    keywords?: string[];            // Keywords that trigger this handler
    interactive_ids?: string[];     // Interactive IDs that trigger this handler
  };
  dependencies?: {
    templates?: string[];           // Required templates
    attributes?: string[];          // Required attributes
    services?: string[];            // Required services
  };
  tags?: string[];                  // Handler tags
  source_file?: string;             // Source file path
  source_line?: number;             // Source line number

  // Only in search results:
  match_score?: number;             // 0-1 relevance score
  match_reason?: string;            // Explanation of why it matched
}
```

## UI Components

### Search Bar

- Real-time search with 300ms debounce
- Clear button appears when query is entered
- Searches across method name, display name, description, and tags

### Filter Sidebar

Three filter sections:

1. **Handler Type**: Filter by state, keyword, interactive, or action handlers
2. **Category**: Filter by business category (onboarding, navigation, forms, etc.)
3. **Status**: Filter by stability (stable, experimental, deprecated)
4. **Sort By**: Dropdown to sort results

**Clear All Filters** button appears when any filter is active.

### Main Content Area

- **Loading State**: Spinner with "Loading handlers..." message
- **Error State**: Error icon with error message and "Retry" button
- **Empty State**: Empty icon with "No handlers found" message
- **Handlers List**: Grouped by category with collapsible sections

Each handler item shows:
- Icon (based on handler type)
- Display name
- Status badge
- Description
- Method name
- Triggers count
- Dependencies count
- Match score (in search results)

### Preview Panel (Optional)

When hovering over a handler, the preview panel shows:
- Method name
- Triggers (state IDs, keywords, interactive IDs)
- Dependencies (templates, attributes, services)
- Tags
- Source location

### Footer

- Count of visible handlers vs total
- Cancel button
- Select Handler button (disabled until selection)

## Keyboard Shortcuts

- **Escape**: Close dialog
- **Enter**: Select current handler (if one is selected)

## API Integration

The component uses the `useHandlerMethods` composable which provides:

### API Endpoints

1. **List Handlers**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods`
   - Filters: `handler_type`, `category`, `status`, `search`
   - Cached for 5 minutes

2. **Search Handlers**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/search`
   - Query parameter: `q`
   - Returns results with match scores

3. **Get Handler Details**: `GET /api/v1/accounts/:account_id/agent_bots/:bot_id/handler_methods/:method_name`
   - Used for preview panel (on hover)

### Caching Strategy

- **List requests** (without search) are cached for 5 minutes
- **Search requests** bypass cache (always fresh)
- Cache can be cleared manually via `clearCache()` method

## Styling

All styling uses **Tailwind CSS** utility classes. Key design elements:

- **Colors**: n-blue-8 for primary, n-slate-* for neutrals
- **Spacing**: Consistent gap-* and p-* spacing
- **Transitions**: Smooth transition-all for interactive elements
- **Responsive**: Grid layout adjusts for different screen sizes
- **Accessibility**: Focus rings, hover states, keyboard navigation

## I18n Support

All user-facing text uses the `useI18n` composable with keys under `AGENT_BOTS.HANDLER_METHODS.*`.

Example keys:
- `AGENT_BOTS.HANDLER_TYPES.STATE`
- `AGENT_BOTS.HANDLER_CATEGORIES.ONBOARDING`
- `AGENT_BOTS.HANDLER_METHODS.LOADING`

## Performance Considerations

1. **Debounced Search**: 300ms debounce prevents excessive API calls
2. **Caching**: 5-minute cache for list requests
3. **Lazy Preview**: Handler details only loaded on hover
4. **Virtual Scrolling**: Not needed (handler lists typically < 100 items)

## Error Handling

- **Loading State**: Shows spinner during initial load
- **Error State**: Displays error message with retry button
- **Empty State**: Shows when no results match filters
- **API Errors**: Caught and displayed to user

## Testing

See `HandlerMethodsBrowser.example.vue` for a standalone example demonstrating:
- Opening the browser
- Handling handler selection
- Displaying selected handler info

## Backend Requirements

The component requires these backend endpoints to be implemented:

1. `HandlerMethodsController#index` - List all handlers
2. `HandlerMethodsController#show` - Get handler details
3. `HandlerMethodsController#search` - Search handlers

See `docs/bot-studio/HANDLER_METHODS_ARCHITECTURE.md` for complete backend architecture.

## Related Components

- **HandlerMethodSelector**: Autocomplete dropdown for inline selection
- **HandlerMethodEditor**: Full editor for viewing/editing handler configuration
- **useHandlerMethods**: Composable for API integration

## Future Enhancements

Potential improvements for future phases:

1. **Favorites/Recently Used**: Quick access to frequently used handlers
2. **Handler Testing**: Test handlers with mock data in the browser
3. **Code Preview**: View handler source code inline
4. **Bulk Selection**: Select multiple handlers at once
5. **Custom Sorting**: User-defined sort order
6. **Filter Presets**: Save and load filter combinations
7. **Export List**: Export handler list as CSV/JSON

## Troubleshooting

### Handler list is empty

- Check that `botId` prop is correct
- Verify bot has a `bot_type` set
- Check browser console for API errors
- Ensure backend has handler metadata defined

### Search not working

- Verify search endpoint is implemented
- Check that handler metadata includes searchable fields
- Look for console errors during search

### Preview not showing

- Verify show endpoint returns full handler details
- Check that handler metadata is properly structured
- Ensure source location is available in metadata

## License

Part of Chatwoot project. See main LICENSE file.
