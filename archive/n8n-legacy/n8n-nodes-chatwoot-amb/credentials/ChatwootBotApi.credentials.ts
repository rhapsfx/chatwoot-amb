import { ICredentialType, INodeProperties } from 'n8n-workflow';

export class ChatwootBotApi implements ICredentialType {
	name = 'chatwootBotApi';
	displayName = 'Chatwoot Bot API';
	documentationUrl =
		'https://www.chatwoot.com/docs/product/channels/live-chat/integrations/chatwoot-bot';
	properties: INodeProperties[] = [
		{
			displayName: 'Chatwoot URL',
			name: 'chatwootUrl',
			type: 'string',
			default: 'https://app.chatwoot.com',
			required: true,
			placeholder: 'https://app.chatwoot.com',
			description: 'Your Chatwoot instance URL (without trailing slash)',
		},
		{
			displayName: 'API Access Token',
			name: 'apiToken',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			required: true,
			description: 'Bot API access token from Chatwoot (Settings → Agent Bots → Your Bot)',
		},
	];
}
