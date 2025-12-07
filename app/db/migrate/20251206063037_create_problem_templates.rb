# frozen_string_literal: true

class CreateProblemTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :problem_templates do |t|
      t.references :problem, null: false, foreign_key: true
      t.references :programming_language, null: false, foreign_key: true
      t.text :template_code, null: false
      t.string :function_signature
      t.timestamps
    end

    add_index :problem_templates, [:problem_id, :programming_language_id], 
              unique: true, 
              name: 'index_problem_templates_on_problem_and_language'
  end
end
