class CreateSharedAppleImages < ActiveRecord::Migration[7.1]
  def change
    create_table :shared_apple_images do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :identifier, null: false
      t.string :image_type, null: false, default: 'system'
      t.text :description
      t.string :original_name
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :shared_apple_images, [:account_id, :identifier], unique: true
    add_index :shared_apple_images, :image_type
  end
end
