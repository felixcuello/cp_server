class ProblemTag < ActiveRecord::Migration[7.2]
  def change
    create_table :problem_tags do |t|
      t.belongs_to :problem, null: false, foreign_key: true
      t.belongs_to :tag, null: false, foreign_key: true
    end
  end
end
