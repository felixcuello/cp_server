class AddIgnoreOutputLineOrderToProblems < ActiveRecord::Migration[7.2]
  def change
    add_column :problems, :ignore_output_line_order, :boolean, default: false, null: false
  end
end
