# frozen_string_literal: true

class CreateSandboxAccessTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :sandbox_access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :label
      t.datetime :valid_from, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :sandbox_access_tokens, :token, unique: true
  end
end
