<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import StateConfig from './config/StateConfig.vue';
import IntentConfig from './config/IntentConfig.vue';
import TemplateConfig from './config/TemplateConfig.vue';
import ActionConfig from './config/ActionConfig.vue';
import ConditionConfig from './config/ConditionConfig.vue';

const props = defineProps({
  selectedNode: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update', 'close']);

const { t } = useI18n();

const configComponent = computed(() => {
  if (!props.selectedNode) return null;

  const componentMap = {
    state: StateConfig,
    intent: IntentConfig,
    template: TemplateConfig,
    action: ActionConfig,
    condition: ConditionConfig,
  };

  return componentMap[props.selectedNode.type];
});

const nodeData = ref(null);

watch(
  () => props.selectedNode,
  newNode => {
    if (newNode) {
      nodeData.value = { ...newNode.data };
    }
  },
  { immediate: true }
);

const saveConfig = () => {
  emit('update', {
    id: props.selectedNode.id,
    data: nodeData.value,
  });
};
</script>

<template>
  <div v-if="selectedNode" class="node-config-panel">
    <div class="panel-header">
      <h3 class="text-base font-semibold text-n-slate-12 capitalize">
        {{ t('AGENT_BOTS.STUDIO.CONFIGURE') }} {{ selectedNode.type }}
      </h3>
      <Button
        icon="i-lucide-x"
        size="xs"
        variant="faded"
        @click="emit('close')"
      />
    </div>

    <div class="panel-content">
      <component :is="configComponent" v-model="nodeData" @save="saveConfig" />
    </div>

    <div class="panel-footer">
      <Button variant="faded" @click="emit('close')">
        {{ t('GENERAL_SETTINGS.CANCEL') }}
      </Button>
      <Button @click="saveConfig">{{ t('GENERAL_SETTINGS.SAVE') }}</Button>
    </div>
  </div>
  <div v-else />
</template>

<style scoped>
.node-config-panel {
  position: absolute;
  right: 0;
  top: 0;
  width: 400px;
  height: 100%;
  background: white;
  border-left: 1px solid var(--n-weak);
  display: flex;
  flex-direction: column;
  z-index: 10;
}

.panel-header {
  padding: 16px;
  border-bottom: 1px solid var(--n-weak);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.panel-content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

.panel-footer {
  padding: 16px;
  border-top: 1px solid var(--n-weak);
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}
</style>
