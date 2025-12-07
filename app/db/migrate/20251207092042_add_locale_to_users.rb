class AddLocaleToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :locale, :string, default: 'en', null: false
    add_index :users, :locale
  end
end
