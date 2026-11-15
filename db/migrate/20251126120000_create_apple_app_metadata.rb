class CreateAppleAppMetadata < ActiveRecord::Migration[7.1]
  def change
    create_table :apple_app_metadata do |t|
      t.string :bundle_id, null: false
      t.string :app_name
      t.string :developer_name
      t.string :app_icon_url
      t.string :app_store_url
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :apple_app_metadata, :bundle_id, unique: true
  end
end
