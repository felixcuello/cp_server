# frozen_string_literal: true

class Constraint < ApplicationRecord
  belongs_to :problem
  validates :description, presence: true
  validates :sort_order, presence: true
end
