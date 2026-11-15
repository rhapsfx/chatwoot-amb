# frozen_string_literal: true

class AddAttachmentMetadataToMessageTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :message_templates, :attachment_metadata, :jsonb, default: {}
    add_index :message_templates, :attachment_metadata, using: :gin
  end
end
