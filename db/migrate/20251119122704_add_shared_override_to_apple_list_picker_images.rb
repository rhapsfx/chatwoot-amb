class AddSharedOverrideToAppleListPickerImages < ActiveRecord::Migration[7.1]
  def change
    add_column :apple_list_picker_images, :shared_override, :boolean, default: false, null: false
    add_index :apple_list_picker_images, [:inbox_id, :shared_override]
  end
end
