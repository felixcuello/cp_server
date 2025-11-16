# frozen_string_literal: true

class UserProblemStatus < ApplicationRecord
  belongs_to :user
  belongs_to :problem
  
  validates :status, presence: true, inclusion: { in: %w[solved attempted unattempted] }
  validates :user_id, uniqueness: { scope: :problem_id }
  
  scope :solved, -> { where(status: 'solved') }
  scope :attempted, -> { where(status: 'attempted') }
end
