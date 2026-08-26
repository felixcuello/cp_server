# frozen_string_literal: true

class CreateSandboxAccessTokenRuns < ActiveRecord::Migration[7.2]
  def up
    create_table :sandbox_access_token_runs do |t|
      t.references :sandbox_access_token, null: false, foreign_key: true, index: false
      t.references :sandbox_access_token_checkin, null: false, foreign_key: true, index: false
      t.references :programming_language, null: false, foreign_key: true
      t.text :source_code, null: false
      t.text :stdin, null: false
      t.text :stdout
      t.text :stderr
      t.string :status, null: false, default: "submitted"
      t.integer :runtime_ms
      t.datetime :created_at, null: false
      t.datetime :finished_at
    end

    add_index :sandbox_access_token_runs,
              [:sandbox_access_token_id, :created_at],
              name: "index_sandbox_runs_on_token_and_created_at"
    add_index :sandbox_access_token_runs,
              [:sandbox_access_token_checkin_id, :created_at],
              name: "index_sandbox_runs_on_checkin_and_created_at"
  end

  def down
    drop_table :sandbox_access_token_runs
  end
end
