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
      :value="formatToPercent(resolutionRate)"
    />
    <reporting-metric-card
      :label="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.LABEL')"
      :info-text="$t('BOT_REPORTS.METRIC.HANDOFF_RATE.TOOLTIP')"
      :value="formatToPercent(handoffRate)"
    />
  </div>
</template>
<script>
import ReportingMetricCard from './ReportingMetricCard.vue';
import ReportsAPI from 'dashboard/api/reports';

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
  watch: {
    filters: {
      deep: true,
      handler() {
        this.fetchMetrics();
      },
    },
  },
  methods: {
    formatToPercent(value) {
      return value ? `${value}%` : '--';
    },
    fetchMetrics() {
      if (!this.filters.to || !this.filters.from) {
        return;
      }
      ReportsAPI.getBotMetrics(this.filters).then(response => {
        this.conversationCount = response.data.conversation_count;
        this.messageCount = response.data.message_count;
        this.resolutionRate = response.data.resolution_rate;
        this.handoffRate = response.data.handoff_rate;
      });
    },
  },
};
</script>
