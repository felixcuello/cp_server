# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :problem_tags
  has_many :problems, through: :problem_tags
end
