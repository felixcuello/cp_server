class ChangeExamplesInputToMediumtext < ActiveRecord::Migration[7.2]
  def up
    change_column :examples, :input, :mediumtext
  end

  def down
    change_column :examples, :input, :text
  end
end
