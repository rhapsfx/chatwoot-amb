import { FEATURE_FLAGS } from '../../../../featureFlags';
import Bot from './Index.vue';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import { AGENT_BOT_PERMISSIONS } from '../../../../constants/permissions.js';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/agent-bots'),
      meta: {
        permissions: ['administrator', AGENT_BOT_PERMISSIONS],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'agent_bots',
          component: Bot,
          meta: {
            featureFlag: FEATURE_FLAGS.AGENT_BOTS,
            permissions: ['administrator', AGENT_BOT_PERMISSIONS],
          },
        },
      ],
    },
  ],
};
