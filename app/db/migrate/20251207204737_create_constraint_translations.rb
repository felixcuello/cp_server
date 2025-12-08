class CreateConstraintTranslations < ActiveRecord::Migration[7.2]
  def change
    create_table :constraint_translations do |t|
      t.references :constraint, null: false, foreign_key: true
      t.string :locale, null: false
      t.text :description, null: false
      t.timestamps
    end
    
    add_index :constraint_translations, [:constraint_id, :locale], unique: true
    add_index :constraint_translations, :locale
  end
end
