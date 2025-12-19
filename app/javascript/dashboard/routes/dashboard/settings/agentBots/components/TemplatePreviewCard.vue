<script setup>
import { computed } from 'vue';

const props = defineProps({
  template: {
    type: Object,
    required: true,
  },
});

// Extract preview data based on template type
const preview = computed(() => {
  const { name, type, data } = props.template;

  switch (type) {
    case 'list_picker':
      return {
        title: data.received_message?.title || 'List Picker',
        subtitle: `${(data.sections || []).length} sections`,
        icon: 'i-lucide-list',
        details: (data.sections || []).map(s => ({
          label: s.title,
          value: `${(s.items || []).length} items`,
        })),
      };

    case 'time_picker':
      return {
        title: data.received_message?.title || 'Time Picker',
        subtitle: data.reply_message?.title || '',
        icon: 'i-lucide-calendar',
        details: [],
      };

    case 'form':
    case 'apple_form':
      return {
        title: data.received_message?.title || 'Form',
        subtitle: `${(data.pages || []).length} pages`,
        icon: 'i-lucide-file-text',
        details: (data.pages || []).map(p => ({
          label: p.title || `Page ${data.pages.indexOf(p) + 1}`,
          value: `${(p.questions || []).length} questions`,
        })),
      };

    case 'rich_link':
      return {
        title: data.title || 'Rich Link',
        subtitle: data.url || '',
        icon: 'i-lucide-link',
        details: [],
      };

    default:
      return {
        title: name,
        subtitle: type,
        icon: 'i-lucide-message-square',
        details: [],
      };
  }
});
</script>

<template>
  <div
    class="mt-2 p-3 bg-n-slate-2 border border-n-slate-6 rounded-lg space-y-2"
  >
    <!-- Header -->
    <div class="flex items-start gap-2">
      <div
        class="w-8 h-8 rounded flex items-center justify-center bg-n-slate-4 flex-shrink-0"
      >
        <i class="w-4 h-4 text-n-slate-11" :class="[preview.icon]" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="font-medium text-sm text-n-slate-12 truncate">
          {{ preview.title }}
        </div>
        <div v-if="preview.subtitle" class="text-xs text-n-slate-10 truncate">
          {{ preview.subtitle }}
        </div>
      </div>
      <div
        class="px-2 py-0.5 bg-n-blue-3 text-n-blue-11 text-xs rounded font-medium"
      >
        {{ template.type }}
      </div>
    </div>

    <!-- Details -->
    <div v-if="preview.details.length > 0" class="space-y-1 pl-10">
      <div
        v-for="(detail, i) in preview.details.slice(0, 3)"
        :key="i"
        class="flex items-center justify-between text-xs"
      >
        <span class="text-n-slate-11">{{ detail.label }}</span>
        <span class="text-n-slate-10 font-mono">{{ detail.value }}</span>
      </div>
      <div
        v-if="preview.details.length > 3"
        class="text-xs text-n-slate-9 italic"
      >
        {{ `+${preview.details.length - 3} more` }}
      </div>
    </div>
  </div>
</template>
