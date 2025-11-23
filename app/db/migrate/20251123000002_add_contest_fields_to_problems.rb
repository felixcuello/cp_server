class AddContestFieldsToProblems < ActiveRecord::Migration[7.2]
  def change
    add_reference :problems, :contest, null: true, foreign_key: true
    add_column :problems, :hidden, :boolean, default: false, null: false
    add_index :problems, :hidden
  end
end
