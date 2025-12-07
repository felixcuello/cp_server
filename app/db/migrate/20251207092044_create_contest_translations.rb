class CreateContestTranslations < ActiveRecord::Migration[7.2]
  def change
    create_table :contest_translations do |t|
      t.references :contest, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :name, null: false
      t.text :description
      t.text :rules
      t.timestamps
    end
    
    add_index :contest_translations, [:contest_id, :locale], unique: true
    add_index :contest_translations, :locale
  end
end
