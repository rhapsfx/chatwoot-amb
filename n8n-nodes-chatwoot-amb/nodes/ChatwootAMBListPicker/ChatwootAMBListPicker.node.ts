import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBListPicker implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB List Picker',
		name: 'chatwootAMBListPicker',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send List Picker to Apple Messages',
		description: 'Send Apple Messages for Business List Picker with images and sections',
		defaults: {
			name: 'AMB List Picker',
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
				hint: 'Use expression: {{$json["conversation"]["id"]}} if coming from webhook',
			},
			{
				displayName: 'Template ID',
				name: 'templateId',
				type: 'number',
				default: '',
				required: true,
				description: 'List Picker template ID from Chatwoot',
				hint: 'Find this in Chatwoot → Settings → Templates',
			},
			{
				displayName: 'Title',
				name: 'title',
				type: 'string',
				default: 'Select an option',
				required: true,
				description: 'Main title for the list picker',
			},
			{
				displayName: 'Sections',
				name: 'sections',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Section',
				default: {},
				description: 'Sections containing list items',
				options: [
					{
						name: 'section',
						displayName: 'Section',
						values: [
							{
								displayName: 'Section Title',
								name: 'title',
								type: 'string',
								default: '',
								description: 'Title for this section',
							},
							{
								displayName: 'Multiple Selection',
								name: 'multipleSelection',
								type: 'boolean',
								default: false,
								description: 'Whether to allow selecting multiple items from this section',
							},
							{
								displayName: 'Items',
								name: 'items',
								type: 'fixedCollection',
								typeOptions: {
									multipleValues: true,
								},
								placeholder: 'Add Item',
								default: {},
								description: 'Items in this section',
								options: [
									{
										name: 'item',
										displayName: 'Item',
										values: [
											{
												displayName: 'Identifier',
												name: 'identifier',
												type: 'string',
												default: '',
												required: true,
												description: 'Unique identifier for this item',
												hint: 'This value will be returned when user selects this item',
											},
											{
												displayName: 'Title',
												name: 'title',
												type: 'string',
												default: '',
												required: true,
												description: 'Item title (displayed to user)',
											},
											{
												displayName: 'Subtitle',
												name: 'subtitle',
												type: 'string',
												default: '',
												description: 'Item subtitle (optional)',
											},
											{
												displayName: 'Image Identifier',
												name: 'image_identifier',
												type: 'string',
												default: '',
												description: 'Identifier of image to display with this item',
												hint: 'Must match an identifier from the Images section below',
											},
											{
												displayName: 'Style',
												name: 'style',
												type: 'options',
												options: [
													{
														name: 'Small',
														value: 'small',
														description: 'Small image style',
													},
													{
														name: 'Large',
														value: 'large',
														description: 'Large image style (default)',
													},
												],
												default: 'large',
												description: 'Image display style',
											},
										],
									},
								],
							},
						],
					},
				],
			},
			{
				displayName: 'Images',
				name: 'images',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Image',
				default: {},
				description: 'Images to include with the list picker',
				options: [
					{
						name: 'image',
						displayName: 'Image',
						values: [
							{
								displayName: 'Identifier',
								name: 'identifier',
								type: 'string',
								default: '',
								required: true,
								description: 'Unique identifier for this image',
								hint: 'Use this identifier in items above to reference this image',
							},
							{
								displayName: 'Image Data (Base64)',
								name: 'data',
								type: 'string',
								typeOptions: {
									rows: 4,
								},
								default: '',
								required: true,
								description: 'Base64-encoded image data',
								placeholder: 'data:image/png;base64,iVBORw0KGgo...',
								hint: 'Must include data URI prefix (e.g., data:image/png;base64,...)',
							},
						],
					},
				],
			},
			{
				displayName: 'Received Message Options',
				name: 'receivedMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the received message (picker display)',
				options: [
					{
						displayName: 'Title',
						name: 'received_title',
						type: 'string',
						default: '',
						description: 'Custom title for received message',
						placeholder: 'Select your preference',
					},
					{
						displayName: 'Image Identifier',
						name: 'received_image_identifier',
						type: 'string',
						default: '',
						description: 'Image to display with received message',
					},
				],
			},
			{
				displayName: 'Reply Message Options',
				name: 'replyMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the reply message (after selection)',
				options: [
					{
						displayName: 'Title Template',
						name: 'reply_title',
						type: 'string',
						default: 'Selected: ${item.title}',
						description: 'Template for reply message title',
						placeholder: 'You selected: ${item.title}',
						hint: 'Use ${item.title} to include selected item title',
					},
					{
						displayName: 'Image Identifier',
						name: 'reply_image_identifier',
						type: 'string',
						default: '',
						description: 'Image to display with reply message',
						hint: 'Will auto-use received image if not specified',
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
				const title = this.getNodeParameter('title', i) as string;

				// Build sections
				const sectionsParam = this.getNodeParameter('sections', i, {}) as any;
				const sections = sectionsParam.section || [];

				const formattedSections = sections.map((section: any, idx: number) => {
					const items = section.items?.item || [];
					return {
						title: section.title || '',
						multipleSelection: section.multipleSelection || false,
						order: idx,
						items: items.map((item: any, itemIdx: number) => ({
							identifier: item.identifier,
							title: item.title,
							subtitle: item.subtitle || '',
							image_identifier: item.image_identifier || '',
							style: item.style || 'large',
							order: itemIdx,
						})),
					};
				});

				// Build images
				const imagesParam = this.getNodeParameter('images', i, {}) as any;
				const images = imagesParam.image || [];

				const formattedImages = images.map((img: any) => ({
					identifier: img.identifier,
					data: img.data,
				}));

				// Build received/reply messages
				const receivedMessage = this.getNodeParameter('receivedMessage', i, {}) as any;
				const replyMessage = this.getNodeParameter('replyMessage', i, {}) as any;

				// Prepare request body
				const body = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
					parameters: {
						title,
						sections: formattedSections,
						images: formattedImages,
						...receivedMessage,
						...replyMessage,
					},
				};

				// Make API request
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
