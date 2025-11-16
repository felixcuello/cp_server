class AddStatisticsToProblems < ActiveRecord::Migration[7.2]
  def change
    add_column :problems, :total_submissions, :integer, default: 0, null: false
    add_column :problems, :accepted_submissions, :integer, default: 0, null: false
    
    add_index :problems, :total_submissions
    add_index :problems, :accepted_submissions
  end
end
