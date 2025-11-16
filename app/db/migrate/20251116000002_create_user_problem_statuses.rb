class CreateUserProblemStatuses < ActiveRecord::Migration[7.2]
  def change
    create_table :user_problem_statuses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true
      t.string :status, null: false  # 'solved', 'attempted', 'unattempted'
      t.datetime :first_solved_at
      t.integer :attempts, default: 0, null: false

      t.timestamps
    end
    
    add_index :user_problem_statuses, [:user_id, :problem_id], unique: true
    add_index :user_problem_statuses, :status
  end
end
