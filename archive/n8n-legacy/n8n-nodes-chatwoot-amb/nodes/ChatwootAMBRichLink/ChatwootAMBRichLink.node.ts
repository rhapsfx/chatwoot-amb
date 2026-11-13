import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBRichLink implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB Rich Link',
		name: 'chatwootAMBRichLink',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send Rich Link to Apple Messages',
		description: 'Send Apple Messages for Business Rich Link with preview',
		defaults: {
			name: 'AMB Rich Link',
		},
		inputs: ['main'],
		outputs: ['main'],
		credentials: [
			{
				name: 'chatwootBotApi',
				required: true,
			},
		],
		properties: [
			{
				displayName: 'Account ID',
				name: 'accountId',
				type: 'number',
				default: 1,
				required: true,
				description: 'Chatwoot account ID',
			},
			{
				displayName: 'Conversation ID',
				name: 'conversationId',
				type: 'string',
				default: '={{$json["conversation"]["id"]}}',
				required: true,
				description: 'Conversation ID to send the message to',
			},
			{
				displayName: 'Template ID',
				name: 'templateId',
				type: 'number',
				default: '',
				required: true,
				description: 'Rich Link template ID from Chatwoot',
			},
			{
				displayName: 'Title',
				name: 'title',
				type: 'string',
				default: 'Check out our website!',
				required: true,
				description: 'Link card title',
			},
			{
				displayName: 'Subtitle',
				name: 'subtitle',
				type: 'string',
				default: '',
				description: 'Link card subtitle or description',
				typeOptions: {
					rows: 2,
				},
			},
			{
				displayName: 'URL',
				name: 'url',
				type: 'string',
				default: '',
				required: true,
				description: 'Target URL for the link',
				placeholder: 'https://example.com',
			},
			{
				displayName: 'Image URL',
				name: 'imageUrl',
				type: 'string',
				default: '',
				description: 'URL of the preview image',
				placeholder: 'https://example.com/image.jpg',
				hint: 'Publicly accessible image URL',
			},
			{
				displayName: 'Open in Safari',
				name: 'openInSafari',
				type: 'boolean',
				default: false,
				description: 'Whether to open the link in Safari instead of in-app browser',
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const returnData: INodeExecutionData[] = [];

		for (let i = 0; i < items.length; i++) {
			try {
				// Get credentials
				const credentials = await this.getCredentials('chatwootBotApi');
				const chatwootUrl = (credentials.chatwootUrl as string).replace(/\/$/, '');
				const botToken = credentials.apiToken as string;

				// Get node parameters
				const accountId = this.getNodeParameter('accountId', i) as number;
				const conversationId = this.getNodeParameter('conversationId', i) as string;
				const templateId = this.getNodeParameter('templateId', i) as number;
				const title = this.getNodeParameter('title', i) as string;
				const subtitle = this.getNodeParameter('subtitle', i, '') as string;
				const url = this.getNodeParameter('url', i) as string;
				const imageUrl = this.getNodeParameter('imageUrl', i, '') as string;
				const openInSafari = this.getNodeParameter('openInSafari', i, false) as boolean;

				const body = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
					parameters: {
						title,
						subtitle,
						url,
						imageUrl,
						openInSafari,
					},
				};

				const options = {
					method: 'POST' as const,
					url: `${chatwootUrl}/api/v1/accounts/${accountId}/bot_templates/send_message`,
					headers: {
						api_access_token: botToken,
						'Content-Type': 'application/json',
					},
					body,
					json: true,
				};

				const response = await this.helpers.request(options);

				returnData.push({
					json: response,
					pairedItem: { item: i },
				});
			} catch (error) {
				if (this.continueOnFail()) {
					returnData.push({
						json: {
							error: (error as Error).message,
						},
						pairedItem: { item: i },
					});
					continue;
				}
				throw new NodeOperationError(this.getNode(), error as Error);
			}
		}

		return [returnData];
	}
}
