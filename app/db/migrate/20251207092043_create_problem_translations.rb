class CreateProblemTranslations < ActiveRecord::Migration[7.2]
  def change
    create_table :problem_translations do |t|
      t.references :problem, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.timestamps
    end
    
    add_index :problem_translations, [:problem_id, :locale], unique: true
    add_index :problem_translations, :locale
  end
end
