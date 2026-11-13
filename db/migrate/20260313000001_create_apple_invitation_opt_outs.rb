class CreateAppleInvitationOptOuts < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_invitation_opt_outs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.references :inbox, null: false, foreign_key: true
      t.datetime :opted_out_at, null: false
      t.jsonb :reference_ids, default: []
      t.timestamps
    end

    add_index :apple_invitation_opt_outs, [:account_id, :phone_number, :inbox_id],
              unique: true, name: 'idx_apple_inv_opt_outs_unique'
  end
end
