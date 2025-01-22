class Submission < ActiveRecord::Migration[7.2]
  def change
    create_table :submissions do |t|
      t.belongs_to :problem, null: false, foreign_key: true
      t.belongs_to :programming_language, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true

      t.text :source_code, null: false
      t.text :compiler_output
      t.text :interpreter_output

      t.integer :memory_used
      t.integer :time_used

      t.string :status, null: false, default: :queued

      t.timestamps
    end
  end
end
