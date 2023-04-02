class Import::ProcessFromSelfHostedService
  MODELS_TO_IMPORT = [CannedResponse, Label, Team, CustomAttributeDefinition].freeze
  ATTRIBUTES_TO_IMPORT = {
    'canned_responses' => %w[title content short_code],
    'labels' => %w[color description show_in_sidebar title],
    'teams' => %w[name description allow_auto_assign],
    'custom_attribute_definitions' => %w[attribute_description attribute_display_name attribute_display_type attribute_key attribute_model
                                         attribute_values default_value]
  }.freeze

  def initialize(account_object, external_account_id, database_config)
    @account_object = account_object
    @external_account_id = external_account_id
    @database_config = database_config.merge({
                                               adapter: 'postgresql',
                                               encoding: 'unicode'
                                             })
  end

  def perform
    MODELS_TO_IMPORT.each do |model|
      # Create a dynamic subclass of the model with the external connection established
      external_model = get_external_model(model)

      # Fetch the data from the external account
      external_account_data = fetch_external_account_data(external_model)

      # Import the data to the local account
      import_data_to_local_account(external_account_data, model)
    end
  end

  private

  def get_external_model(model)
    klass = Import::ExternalModel
    klass.table_name = model.table_name
    klass.establish_connection(@database_config)
    klass
  end

  def fetch_external_account_data(external_model)
    external_model.where(account_id: @external_account_id)
  end

  def import_data_to_local_account(external_account_data, model)
    # Update the account_id and save the records to the local database

    records_to_import = []
    external_account_data.each do |record|
      new_record = model.new
      new_record.assign_attributes(record.attributes.slice(*ATTRIBUTES_TO_IMPORT[model.table_name]))
      new_record.account_id = @account_object.id
      records_to_import << new_record
    end

    model.import records_to_import, on_duplicate_key_ignore: true
  end
end
