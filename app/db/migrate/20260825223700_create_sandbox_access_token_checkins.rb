# frozen_string_literal: true

class CreateSandboxAccessTokenCheckins < ActiveRecord::Migration[7.2]
  def up
    create_table :sandbox_access_token_checkins do |t|
      t.references :sandbox_access_token, null: false, foreign_key: true, index: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :id_type, null: false
      t.string :document_number, null: false
      t.string :ip_address, null: false
      t.datetime :created_at, null: false
    end

    add_index :sandbox_access_token_checkins,
              [:sandbox_access_token_id, :id_type, :document_number],
              unique: true,
              name: "index_sandbox_checkins_on_token_and_identity"
    add_index :sandbox_access_token_checkins,
              [:id_type, :document_number],
              name: "index_sandbox_checkins_on_identity"
  end

  def down
    drop_table :sandbox_access_token_checkins
  end
end
