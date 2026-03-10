class ChangeExamplesInputOutputToLongtext < ActiveRecord::Migration[7.2]
  def up
    change_column :examples, :input, :longtext
    change_column :examples, :output, :longtext
  end

  def down
    change_column :examples, :input, :mediumtext
    change_column :examples, :output, :mediumtext
  end
end
