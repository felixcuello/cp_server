class CreateContestParticipants < ActiveRecord::Migration[7.2]
  def change
    create_table :contest_participants do |t|
      t.references :contest, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.datetime :joined_at, null: false

      t.timestamps
    end

    add_index :contest_participants, [:contest_id, :user_id], unique: true
  end
end
