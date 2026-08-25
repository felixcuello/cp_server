# frozen_string_literal: true

class CreateSandboxAccessTokenLanguages < ActiveRecord::Migration[7.2]
  def up
    create_table :sandbox_access_token_languages do |t|
      t.references :sandbox_access_token, null: false, foreign_key: true
      t.references :programming_language, null: false, foreign_key: true
      t.timestamps
    end

    add_index :sandbox_access_token_languages,
              [:sandbox_access_token_id, :programming_language_id],
              unique: true,
              name: "index_sandbox_token_languages_on_token_and_language"

    execute <<~SQL.squish
      INSERT INTO sandbox_access_token_languages
        (sandbox_access_token_id, programming_language_id, created_at, updated_at)
      SELECT t.id, l.id, UTC_TIMESTAMP(), UTC_TIMESTAMP()
      FROM sandbox_access_tokens t
      CROSS JOIN programming_languages l
    SQL
  end

  def down
    drop_table :sandbox_access_token_languages
  end
end
