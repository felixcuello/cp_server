# frozen_string_literal: true

class Problem < ApplicationRecord
  has_many :examples
  has_many :problem_tags
  has_many :tags, through: :problem_tags

  enum :difficulty, {
    easy: 0,
    medium: 1,
    hard: 2
  }
end
