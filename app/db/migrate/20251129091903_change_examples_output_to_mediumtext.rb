class ChangeExamplesOutputToMediumtext < ActiveRecord::Migration[7.2]
  def up
    change_column :examples, :output, :mediumtext
  end

  def down
    change_column :examples, :output, :text
  end
end
