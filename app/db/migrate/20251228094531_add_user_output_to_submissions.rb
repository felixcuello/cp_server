class AddUserOutputToSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :submissions, :user_output, :mediumtext
  end
end
