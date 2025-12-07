# frozen_string_literal: true

class AddTestingModeToProblems < ActiveRecord::Migration[7.2]
  def change
    add_column :problems, :testing_mode, :string, default: 'stdin_stdout', null: false
    add_index :problems, :testing_mode
  end
end
