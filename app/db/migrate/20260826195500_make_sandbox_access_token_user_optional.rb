# frozen_string_literal: true

# Production created this table before owners existed. Add user_id if missing
# and allow NULL so existing tokens can stay without an owner.
class MakeSandboxAccessTokenUserOptional < ActiveRecord::Migration[7.2]
  def up
    if column_exists?(:sandbox_access_tokens, :user_id)
      change_column_null :sandbox_access_tokens, :user_id, true
      return
    end

    add_reference :sandbox_access_tokens, :user, null: true, foreign_key: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
