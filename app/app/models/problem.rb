# frozen_string_literal: true

class Problem < ApplicationRecord
  has_many :examples
  has_many :problem_tags
  has_many :tags, through: :problem_tags
  has_many :constraints
  has_many :submissions
  has_many :user_problem_statuses

  enum :difficulty, {
    easy: 0,
    medium: 1,
    hard: 2
  }
  
  # Calculate acceptance rate as percentage
  def acceptance_rate
    return 0 if total_submissions.zero?
    ((accepted_submissions.to_f / total_submissions) * 100).round(1)
  end
  
  # Check if user has solved this problem
  def solved_by?(user)
    user_problem_statuses.where(user: user, status: 'solved').exists?
  end
  
  # Check if user has attempted this problem
  def attempted_by?(user)
    user_problem_statuses.where(user: user).where.not(status: 'unattempted').exists?
  end
  
  # Update statistics after a submission
  def update_statistics!
    self.total_submissions = submissions.count
    self.accepted_submissions = submissions.where(status: 'accepted').count
    save!
  end
end

