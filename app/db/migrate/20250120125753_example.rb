class Example < ActiveRecord::Migration[7.2]
  def change
    create_table :examples do |t|
      t.string :input
      t.string :output
      t.integer :sort_order
      t.belongs_to :problem, null: false, foreign_key: true

      t.timestamps
    end
  end
end
