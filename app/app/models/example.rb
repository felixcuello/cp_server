# frozen_string_literal: true

class Example < ApplicationRecord
  belongs_to :problem
  validates :input, presence: true
  validates :output, presence: true
  validates :sort_order, presence: true
  validates :sort_order, numericality: { only_integer: true }
end
