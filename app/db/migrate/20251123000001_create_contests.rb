class CreateContests < ActiveRecord::Migration[7.2]
  def change
    create_table :contests do |t|
      t.string :name, null: false
      t.text :description
      t.text :rules
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :penalty_minutes, default: 0, null: false

      t.timestamps
    end

    add_index :contests, :start_time
    add_index :contests, :end_time
  end
end
