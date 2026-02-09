import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBForm implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB Form',
		name: 'chatwootAMBForm',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send Form to Apple Messages',
		description: 'Send Apple Messages for Business multi-field form',
		defaults: {
			name: 'AMB Form',
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
				description: 'Form template ID from Chatwoot',
			},
			{
				displayName: 'Form Title',
				name: 'title',
				type: 'string',
				default: 'Contact Information',
				required: true,
				description: 'Main title for the form',
			},
			{
				displayName: 'Form Description',
				name: 'description',
				type: 'string',
				default: 'Please fill out your details',
				description: 'Description text for the form',
				typeOptions: {
					rows: 2,
				},
			},
			{
				displayName: 'Show Summary',
				name: 'showSummary',
				type: 'boolean',
				default: true,
				description: 'Whether to show a summary before submitting the form',
			},
			{
				displayName: 'Form Pages',
				name: 'pages',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Page',
				default: {},
				description: 'Pages in the form (multi-page forms supported)',
				options: [
					{
						name: 'page',
						displayName: 'Page',
						values: [
							{
								displayName: 'Page Title',
								name: 'title',
								type: 'string',
								default: 'Page 1',
								description: 'Title for this page',
							},
							{
								displayName: 'Fields',
								name: 'fields',
								type: 'fixedCollection',
								typeOptions: {
									multipleValues: true,
								},
								placeholder: 'Add Field',
								default: {},
								description: 'Form fields on this page',
								options: [
									{
										name: 'field',
										displayName: 'Field',
										values: [
											{
												displayName: 'Identifier',
												name: 'identifier',
												type: 'string',
												default: '',
												required: true,
												description: 'Unique identifier for this field',
												placeholder: 'email',
											},
											{
												displayName: 'Field Type',
												name: 'type',
												type: 'options',
												options: [
													{
														name: 'Text',
														value: 'text',
														description: 'Single-line text input',
													},
													{
														name: 'Email',
														value: 'email',
														description: 'Email address input',
													},
													{
														name: 'Phone',
														value: 'phone',
														description: 'Phone number input',
													},
													{
														name: 'Number',
														value: 'number',
														description: 'Numeric input',
													},
													{
														name: 'Select',
														value: 'select',
														description: 'Dropdown selection',
													},
													{
														name: 'Multi-select',
														value: 'multiselect',
														description: 'Multiple choice selection',
													},
													{
														name: 'Date',
														value: 'date',
														description: 'Date picker',
													},
													{
														name: 'Time',
														value: 'time',
														description: 'Time picker',
													},
												],
												default: 'text',
												description: 'Type of input field',
											},
											{
												displayName: 'Label',
												name: 'label',
												type: 'string',
												default: '',
												required: true,
												description: 'Field label (displayed to user)',
											},
											{
												displayName: 'Required',
												name: 'required',
												type: 'boolean',
												default: false,
												description: 'Whether this field is required',
											},
											{
												displayName: 'Placeholder',
												name: 'placeholder',
												type: 'string',
												default: '',
												description: 'Placeholder text',
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
				displayName: 'Received Message Options',
				name: 'receivedMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the received message (form display)',
				options: [
					{
						displayName: 'Title',
						name: 'title',
						type: 'string',
						default: '',
						description: 'Custom title for received message',
					},
					{
						displayName: 'Image Identifier',
						name: 'imageIdentifier',
						type: 'string',
						default: '',
						description: 'Image to display with form',
					},
					{
						displayName: 'Style',
						name: 'style',
						type: 'options',
						options: [
							{ name: 'Small', value: 'small' },
							{ name: 'Large', value: 'large' },
						],
						default: 'large',
						description: 'Image display style',
					},
				],
			},
			{
				displayName: 'Reply Message Options',
				name: 'replyMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the reply message (after submission)',
				options: [
					{
						displayName: 'Title',
						name: 'title',
						type: 'string',
						default: 'Thank you for your submission!',
						description: 'Reply message title',
					},
					{
						displayName: 'Image Identifier',
						name: 'imageIdentifier',
						type: 'string',
						default: '',
						description: 'Image to display with reply',
					},
					{
						displayName: 'Style',
						name: 'style',
						type: 'options',
						options: [
							{ name: 'Small', value: 'small' },
							{ name: 'Large', value: 'large' },
						],
						default: 'large',
						description: 'Image display style',
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
				description: 'Images to include with the form',
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
				const title = this.getNodeParameter('title', i) as string;
				const description = this.getNodeParameter('description', i, '') as string;
				const showSummary = this.getNodeParameter('showSummary', i, true) as boolean;

				// Build pages
				const pagesParam = this.getNodeParameter('pages', i, {}) as any;
				const pages = pagesParam.page || [];

				const formattedPages = pages.map((page: any) => {
					const fields = page.fields?.field || [];
					return {
						title: page.title,
						fields: fields.map((field: any) => ({
							identifier: field.identifier,
							type: field.type,
							label: field.label,
							required: field.required || false,
							placeholder: field.placeholder || '',
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

				const receivedMessage = this.getNodeParameter('receivedMessage', i, {}) as any;
				const replyMessage = this.getNodeParameter('replyMessage', i, {}) as any;

				const body = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
					parameters: {
						title,
						description,
						pages: formattedPages,
						show_summary: showSummary,
						received_message: receivedMessage,
						reply_message: replyMessage,
						images: formattedImages,
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
