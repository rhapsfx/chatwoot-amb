import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
  TEMPLATE_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import TemplateList from './Index.vue';
import TemplateBuilder from './TemplateBuilder.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/message-templates'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'message_templates_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'message_templates_list',
          meta: {
            permissions: [
              ...ROLES,
              ...CONVERSATION_PERMISSIONS,
              TEMPLATE_PERMISSIONS,
            ],
          },
          component: TemplateList,
        },
        {
          path: 'new',
          name: 'message_template_new',
          meta: {
            permissions: ['administrator', TEMPLATE_PERMISSIONS],
          },
          component: TemplateBuilder,
        },
        {
          path: ':templateId/edit',
          name: 'message_template_edit',
          meta: {
            permissions: ['administrator', TEMPLATE_PERMISSIONS],
          },
          component: TemplateBuilder,
        },
      ],
    },
  ],
};
