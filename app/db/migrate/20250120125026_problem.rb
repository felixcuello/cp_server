class Problem < ActiveRecord::Migration[7.2]
  def change
    create_table :problems do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.integer :difficulty, null: false

      t.timestamps
    end
  end
end
