class Example < ActiveRecord::Migration[7.2]
  def change
    create_table :examples do |t|
      t.text :input
      t.text :output
      t.integer :sort_order
      t.boolean :is_hidden, null: false, default: true
      t.belongs_to :problem, null: false, foreign_key: true

      t.timestamps
    end
  end
end
