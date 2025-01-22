class Problem < ActiveRecord::Migration[7.2]
  def change
    create_table :problems do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.integer :difficulty, null: false
      t.integer :memory_limit_mb, null: false
      t.integer :time_limit_sec, null: false

      t.timestamps
    end
  end
end
