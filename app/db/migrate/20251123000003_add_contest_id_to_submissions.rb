class AddContestIdToSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_reference :submissions, :contest, null: true, foreign_key: true
  end
end
