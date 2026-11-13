import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ChatwootAMBFileAttachment implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Chatwoot AMB File Attachment',
		name: 'chatwootAMBFileAttachment',
		icon: 'file:amb.svg',
		group: ['transform'],
		version: 1,
		subtitle: 'Send File/Attachment via Template',
		description: 'Send files and attachments using Chatwoot templates with automatic attachment handling',
		defaults: {
			name: 'AMB File Attachment',
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
				displayName: 'Template Selection',
				name: 'templateSelection',
				type: 'options',
				options: [
					{
						name: 'Use Template ID',
						value: 'id',
						description: 'Specify template by ID directly',
					},
					{
						name: 'Search Templates',
						value: 'search',
						description: 'Search for template by name or tags',
					},
				],
				default: 'id',
				description: 'How to specify the template to send',
			},
			{
				displayName: 'Template ID',
				name: 'templateId',
				type: 'number',
				default: '',
				required: true,
				displayOptions: {
					show: {
						templateSelection: ['id'],
					},
				},
				description: 'Template ID with file attachments (Settings → Message Templates → Templates with attachments)',
			},
			{
				displayName: 'Template Name',
				name: 'templateName',
				type: 'string',
				default: '',
				required: true,
				displayOptions: {
					show: {
						templateSelection: ['search'],
					},
				},
				description: 'Template name with attachments to search for',
				placeholder: 'USDZ File',
			},
			{
				displayName: 'Parameters',
				name: 'parameters',
				type: 'fixedCollection',
				typeOptions: {
					multipleValues: true,
				},
				placeholder: 'Add Parameter',
				default: {},
				description: 'Template parameters for variable substitution (e.g., {{customer_name}})',
				options: [
					{
						name: 'parameter',
						displayName: 'Parameter',
						values: [
							{
								displayName: 'Key',
								name: 'key',
								type: 'string',
								default: '',
								required: true,
								description: 'Parameter name (without curly braces)',
								placeholder: 'customer_name',
							},
							{
								displayName: 'Value',
								name: 'value',
								type: 'string',
								default: '',
								required: true,
								description: 'Value to substitute',
								placeholder: 'John Doe',
							},
						],
					},
				],
			},
			{
				displayName: 'Additional Options',
				name: 'additionalOptions',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				options: [
					{
						displayName: 'Private',
						name: 'private',
						type: 'boolean',
						default: false,
						description: 'Whether to send as private note (visible only to agents)',
					},
					{
						displayName: 'Return Template Info',
						name: 'returnTemplateInfo',
						type: 'boolean',
						default: false,
						description: 'Whether to return template metadata in response',
					},
					{
						displayName: 'Validate Template',
						name: 'validateTemplate',
						type: 'boolean',
						default: false,
						description: 'Whether to validate template existence before sending',
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
				const templateSelection = this.getNodeParameter('templateSelection', i) as string;

				// Additional options
				const additionalOptions = this.getNodeParameter('additionalOptions', i, {}) as any;
				const isPrivate = additionalOptions.private || false;
				const returnTemplateInfo = additionalOptions.returnTemplateInfo || false;
				const validateTemplate = additionalOptions.validateTemplate || false;

				// Build parameters object
				const parametersParam = this.getNodeParameter('parameters', i, {}) as any;
				const parametersList = parametersParam.parameter || [];
				const parameters: Record<string, string> = {};

				parametersList.forEach((param: any) => {
					if (param.key && param.value) {
						parameters[param.key] = param.value;
					}
				});

				let templateId: number;

				// Handle template selection method
				if (templateSelection === 'search') {
					// Search for template by name
					const templateName = this.getNodeParameter('templateName', i) as string;

					const searchOptions = {
						method: 'GET' as const,
						url: `${chatwootUrl}/api/v1/accounts/${accountId}/bot_templates/search`,
						headers: {
							api_access_token: botToken,
							'Content-Type': 'application/json',
						},
						qs: {
							query: templateName,
							channel: 'apple_messages_for_business',
						},
						json: true,
					};

					const searchResponse = await this.helpers.request(searchOptions);

					if (!searchResponse.templates || searchResponse.templates.length === 0) {
						throw new Error(`Template not found: ${templateName}`);
					}

					// Use first matching template
					templateId = searchResponse.templates[0].id;

					if (returnTemplateInfo) {
						// Store template info for return data
						parameters._templateInfo = JSON.stringify(searchResponse.templates[0]);
					}
				} else {
					// Use template ID directly
					templateId = this.getNodeParameter('templateId', i) as number;
				}

				// Validate template if requested
				if (validateTemplate) {
					const validateOptions = {
						method: 'GET' as const,
						url: `${chatwootUrl}/api/v1/accounts/${accountId}/templates/${templateId}`,
						headers: {
							api_access_token: botToken,
							'Content-Type': 'application/json',
						},
						json: true,
					};

					try {
						await this.helpers.request(validateOptions);
					} catch (error) {
						throw new Error(
							`Template validation failed for ID ${templateId}: ${(error as Error).message}`,
						);
					}
				}

				// Build request body
				const body: any = {
					conversation_id: parseInt(conversationId, 10),
					template_id: templateId,
				};

				// Add parameters if any
				if (Object.keys(parameters).length > 0) {
					body.parameters = parameters;
				}

				// Add private flag if set
				if (isPrivate) {
					body.private = true;
				}

				// Send template message
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

				// Enhance response with metadata
				const enrichedResponse: any = {
					...response,
					metadata: {
						template_id: templateId,
						parameters_used: parameters,
						attachments_sent: response.attachments_sent || 0,
						has_attachments: (response.attachments_sent || 0) > 0,
					},
				};

				returnData.push({
					json: enrichedResponse,
					pairedItem: { item: i },
				});
			} catch (error) {
				if (this.continueOnFail()) {
					returnData.push({
						json: {
							error: (error as Error).message,
							success: false,
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
