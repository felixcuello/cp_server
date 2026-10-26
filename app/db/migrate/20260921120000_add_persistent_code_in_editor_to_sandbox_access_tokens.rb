# frozen_string_literal: true

class AddPersistentCodeInEditorToSandboxAccessTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :sandbox_access_tokens, :persistent_code_in_editor, :boolean, null: false, default: false
  end
end
