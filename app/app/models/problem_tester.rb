# frozen_string_literal: true

class ProblemTester < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language

  validates :tester_code, presence: true
  validates :programming_language_id, uniqueness: { scope: :problem_id }
end
