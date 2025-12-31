import { FEATURE_FLAGS } from '../../../../featureFlags';
import Bot from './Index.vue';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';

// Lazy load BotStudio to avoid circular dependency with dashboard store/routes
const BotStudio = () => import('./BotStudio.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/agent-bots'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'agent_bots',
          component: Bot,
          meta: {
            featureFlag: FEATURE_FLAGS.AGENT_BOTS,
            permissions: ['administrator'],
          },
        },
      ],
    },
    // Bot Studio as standalone route (full-screen, no SettingsWrapper)
    {
      path: frontendURL(
        'accounts/:accountId/settings/agent-bots/:botId/studio'
      ),
      name: 'bot_studio',
      component: BotStudio,
      meta: {
        featureFlag: FEATURE_FLAGS.AGENT_BOTS,
        permissions: ['administrator'],
      },
    },
  ],
};
