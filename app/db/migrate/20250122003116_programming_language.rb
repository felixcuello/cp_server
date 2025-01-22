class ProgrammingLanguage < ActiveRecord::Migration[7.2]
  def change
    create_table :programming_languages do |t|
      t.string :name, null: false

      t.string :compiler_binary
      t.string :compiler_flags

      t.string :interpreter_binary
      t.string :interpreter_flags

      t.integer :memory_limit_mb
      t.integer :time_limit_sec

      t.timestamps
    end
  end
end
