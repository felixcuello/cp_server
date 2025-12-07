# frozen_string_literal: true

class CreateProblemTesters < ActiveRecord::Migration[7.2]
  def change
    create_table :problem_testers do |t|
      t.references :problem, null: false, foreign_key: true
      t.references :programming_language, null: false, foreign_key: true
      t.text :tester_code, null: false
      t.timestamps
    end

    add_index :problem_testers, [:problem_id, :programming_language_id],
              unique: true,
              name: 'index_problem_testers_on_problem_and_language'
  end
end
