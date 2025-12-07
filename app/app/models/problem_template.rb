# frozen_string_literal: true

class ProblemTemplate < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language

  validates :template_code, presence: true
  validates :programming_language_id, uniqueness: { scope: :problem_id }

  def has_template?
    template_code.present?
  end
end
