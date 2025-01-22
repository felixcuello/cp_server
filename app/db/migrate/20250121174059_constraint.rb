class Constraint < ActiveRecord::Migration[7.2]
  def change
    create_table :constraints do |t|
      t.belongs_to :problem, null: false, foreign_key: true
      t.text :description, null: false
      t.integer :sort_order, null: false
    end
  end
end
