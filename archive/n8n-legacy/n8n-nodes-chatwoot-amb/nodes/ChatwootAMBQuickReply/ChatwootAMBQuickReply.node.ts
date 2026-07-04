import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBQuickReply implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB Quick Reply',
		name: 'chatwootAMBQuickReply',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send Quick Reply to Apple Messages',
		description: 'Send Apple Messages for Business Quick Reply buttons',
		defaults: {
			name: 'AMB Quick Reply',
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
				description: 'Quick Reply template ID from Chatwoot',
			},
			{
				displayName: 'Summary Text',
				name: 'summaryText',
				type: 'string',
				default: 'Please select an option',
				required: true,
				description: 'Text displayed above the quick reply buttons',
				typeOptions: {
					rows: 2,
				},
			},
			{
				displayName: 'Quick Reply Items',
				name: 'items',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Quick Reply Button',
				default: {},
				description: 'Quick reply button options',
				options: [
					{
						name: 'item',
						displayName: 'Quick Reply Button',
						values: [
							{
								displayName: 'Identifier',
								name: 'identifier',
								type: 'string',
								default: '',
								required: true,
								description: 'Unique identifier for this button',
								placeholder: 'yes',
								hint: 'This value will be returned when user taps this button',
							},
							{
								displayName: 'Title',
								name: 'title',
								type: 'string',
								default: '',
								required: true,
								description: 'Button text (displayed to user)',
								placeholder: 'Yes, I agree',
								hint: 'Keep it short (max 35 characters recommended)',
							},
						],
					},
				],
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
				const summaryText = this.getNodeParameter('summaryText', i) as string;

				// Build items
				const itemsParam = this.getNodeParameter('items', i, {}) as any;
				const quickReplyItems = itemsParam.item || [];

				const formattedItems = quickReplyItems.map((item: any) => ({
					identifier: item.identifier,
					title: item.title,
				}));

				const body = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
					parameters: {
						summary_text: summaryText,
						items: formattedItems,
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
