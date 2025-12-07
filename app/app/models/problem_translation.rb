# frozen_string_literal: true

class ProblemTranslation < ApplicationRecord
  belongs_to :problem

  validates :locale, presence: true, inclusion: { in: %w[en es] }
  validates :title, presence: true
  validates :description, presence: true
  validates :locale, uniqueness: { scope: :problem_id }
end
