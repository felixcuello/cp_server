class ChangeProblemHiddenDefaultToTrue < ActiveRecord::Migration[7.2]
  def change
    change_column_default :problems, :hidden, from: false, to: true
  end
end
