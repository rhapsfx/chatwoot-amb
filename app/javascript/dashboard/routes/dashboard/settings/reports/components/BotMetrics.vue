<template>
  <div
    class="flex flex-wrap mx-0 bg-white dark:bg-slate-800 rounded-[4px] p-4 mb-5 border border-solid border-slate-75 dark:border-slate-700"
  >
    <reporting-metric-card
      :label="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.TOTAL_CONVERSATIONS.TOOLTIP')"
      :value="conversationCount"
    />
    <reporting-metric-card
      :label="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.TOTAL_RESPONSES.TOOLTIP')"
      :value="messageCount"
    />
    <reporting-metric-card
      :label="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.RESOLUTION_RATE.TOOLTIP')"
      :value="resolutionRate"
    />
    <reporting-metric-card
      :label="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.TOOLTIP')"
      :value="handoffRate"
    />
  </div>
</template>
<script>
import { mapGetters } from 'vuex';
import ReportingMetricCard from './ReportingMetricCard.vue';

export default {
  components: {
    ReportingMetricCard,
  },
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      conversationCount: '0',
      messageCount: '0',
      resolutionRate: '0',
      handoffRate: '0',
    };
  },
  computed: {
    ...mapGetters({
      metrics: 'reports/getBotMetrics',
    }),
  },
};
</script>
