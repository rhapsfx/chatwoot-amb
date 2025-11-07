import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBTimePicker implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB Time Picker',
		name: 'chatwootAMBTimePicker',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send Time Picker to Apple Messages',
		description: 'Send Apple Messages for Business Time Picker for appointment scheduling',
		defaults: {
			name: 'AMB Time Picker',
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
				description: 'Time Picker template ID from Chatwoot',
			},
			{
				displayName: 'Title',
				name: 'title',
				type: 'string',
				default: 'Book Your Appointment',
				required: true,
				description: 'Title for the time picker',
			},
			{
				displayName: 'Description',
				name: 'description',
				type: 'string',
				default: 'Choose your preferred time',
				description: 'Description text for the time picker',
			},
			{
				displayName: 'Available Time Slots',
				name: 'availableSlots',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Time Slot',
				default: {},
				description: 'Available time slots for booking',
				options: [
					{
						name: 'slot',
						displayName: 'Time Slot',
						values: [
							{
								displayName: 'Identifier',
								name: 'identifier',
								type: 'string',
								default: '',
								required: true,
								description: 'Unique identifier for this slot',
								placeholder: '2025-11-03_14',
								hint: 'Format: YYYY-MM-DD_HH',
							},
							{
								displayName: 'Start Time',
								name: 'startTime',
								type: 'string',
								default: '',
								required: true,
								description: 'Start time in ISO 8601 format',
								placeholder: '2025-11-03T14:00+0000',
								hint: 'Format: YYYY-MM-DDTHH:MM+0000',
							},
							{
								displayName: 'Duration (seconds)',
								name: 'duration',
								type: 'number',
								default: 3600,
								required: true,
								description: 'Duration of the appointment in seconds',
								hint: '3600 = 1 hour, 1800 = 30 minutes',
							},
						],
					},
				],
			},
			{
				displayName: 'Timezone Offset (seconds)',
				name: 'timezoneOffset',
				type: 'number',
				default: 0,
				description: 'Timezone offset in seconds',
				hint: 'UTC+8 = 28800, UTC-5 = -18000',
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
						default: 'Booked: ${event.title}',
						description: 'Template for reply message title',
						hint: 'Use ${event.title} to include event title',
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
			{
				displayName: 'Images',
				name: 'images',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Image',
				default: {},
				description: 'Images to include with the time picker',
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
				const timezoneOffset = this.getNodeParameter('timezoneOffset', i, 0) as number;

				// Build time slots
				const slotsParam = this.getNodeParameter('availableSlots', i, {}) as any;
				const slots = slotsParam.slot || [];

				const formattedSlots = slots.map((slot: any) => ({
					identifier: slot.identifier,
					startTime: slot.startTime,
					duration: slot.duration,
				}));

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
						available_slots: formattedSlots,
						timezone_offset: timezoneOffset,
						images: formattedImages,
						...receivedMessage,
						...replyMessage,
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
