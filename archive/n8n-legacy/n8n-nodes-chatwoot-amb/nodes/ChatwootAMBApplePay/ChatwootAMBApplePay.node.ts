import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBApplePay implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB Apple Pay',
		name: 'chatwootAMBApplePay',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send Apple Pay request',
		description: 'Send Apple Messages for Business Apple Pay payment request',
		defaults: {
			name: 'AMB Apple Pay',
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
				description: 'Apple Pay template ID from Chatwoot',
			},
			{
				displayName: 'Title',
				name: 'title',
				type: 'string',
				default: 'Complete Your Purchase',
				required: true,
				description: 'Payment request title',
			},
			{
				displayName: 'Merchant Identifier',
				name: 'merchantIdentifier',
				type: 'string',
				default: 'merchant.com.yourcompany',
				required: true,
				description: 'Your Apple Pay merchant identifier',
				placeholder: 'merchant.com.example',
			},
			{
				displayName: 'Merchant Name',
				name: 'merchantName',
				type: 'string',
				default: 'Your Company',
				required: true,
				description: 'Merchant display name',
			},
			{
				displayName: 'Country Code',
				name: 'countryCode',
				type: 'string',
				default: 'US',
				required: true,
				description: 'Two-letter ISO country code',
				placeholder: 'US',
			},
			{
				displayName: 'Currency Code',
				name: 'currencyCode',
				type: 'string',
				default: 'USD',
				required: true,
				description: 'Three-letter ISO currency code',
				placeholder: 'USD',
			},
			{
				displayName: 'Total Amount',
				name: 'amount',
				type: 'string',
				default: '0.00',
				required: true,
				description: 'Total payment amount',
				placeholder: '120.00',
				hint: 'Format: 00.00 (two decimal places)',
			},
			{
				displayName: 'Total Label',
				name: 'totalLabel',
				type: 'string',
				default: 'Total',
				description: 'Label for the total amount',
			},
			{
				displayName: 'Line Items',
				name: 'lineItems',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Line Item',
				default: {},
				description: 'Individual line items in the payment request',
				options: [
					{
						name: 'item',
						displayName: 'Line Item',
						values: [
							{
								displayName: 'Label',
								name: 'label',
								type: 'string',
								default: '',
								required: true,
								description: 'Line item label',
								placeholder: 'Product Name',
							},
							{
								displayName: 'Amount',
								name: 'amount',
								type: 'string',
								default: '0.00',
								required: true,
								description: 'Line item amount',
								placeholder: '100.00',
							},
							{
								displayName: 'Type',
								name: 'type',
								type: 'options',
								options: [
									{
										name: 'Final',
										value: 'final',
										description: 'Final amount',
									},
									{
										name: 'Pending',
										value: 'pending',
										description: 'Pending amount (may change)',
									},
								],
								default: 'final',
								description: 'Line item type',
							},
						],
					},
				],
			},
			{
				displayName: 'Payment Networks',
				name: 'paymentNetworks',
				type: 'multiOptions',
				options: [
					{
						name: 'Visa',
						value: 'visa',
					},
					{
						name: 'Mastercard',
						value: 'mastercard',
					},
					{
						name: 'American Express',
						value: 'amex',
					},
					{
						name: 'Discover',
						value: 'discover',
					},
					{
						name: 'China UnionPay',
						value: 'chinaUnionPay',
					},
				],
				default: ['visa', 'mastercard', 'amex'],
				description: 'Accepted payment networks',
			},
			{
				displayName: 'Received Message Options',
				name: 'receivedMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the received message',
				options: [
					{
						displayName: 'Title',
						name: 'receivedTitle',
						type: 'string',
						default: '',
						description: 'Custom title for received message',
					},
				],
			},
			{
				displayName: 'Reply Message Options',
				name: 'replyMessage',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				description: 'Options for the reply message',
				options: [
					{
						displayName: 'Title',
						name: 'replyTitle',
						type: 'string',
						default: 'Payment Sent',
						description: 'Reply message title',
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
				const merchantIdentifier = this.getNodeParameter('merchantIdentifier', i) as string;
				const merchantName = this.getNodeParameter('merchantName', i) as string;
				const countryCode = this.getNodeParameter('countryCode', i) as string;
				const currencyCode = this.getNodeParameter('currencyCode', i) as string;
				const amount = this.getNodeParameter('amount', i) as string;
				const totalLabel = this.getNodeParameter('totalLabel', i, 'Total') as string;
				const paymentNetworks = this.getNodeParameter('paymentNetworks', i) as string[];

				// Build line items
				const lineItemsParam = this.getNodeParameter('lineItems', i, {}) as any;
				const lineItems = lineItemsParam.item || [];

				const formattedLineItems = lineItems.map((item: any) => ({
					label: item.label,
					amount: item.amount,
					type: item.type,
				}));

				const receivedMessage = this.getNodeParameter('receivedMessage', i, {}) as any;
				const replyMessage = this.getNodeParameter('replyMessage', i, {}) as any;

				const body = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
					parameters: {
						title,
						merchantIdentifier,
						merchantName,
						countryCode,
						currencyCode,
						amount,
						totalLabel,
						lineItems: formattedLineItems,
						paymentNetworks,
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
