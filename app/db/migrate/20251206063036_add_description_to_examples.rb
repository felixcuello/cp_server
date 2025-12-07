# frozen_string_literal: true

class AddDescriptionToExamples < ActiveRecord::Migration[7.2]
  def change
    add_column :examples, :description, :text
  end
end
