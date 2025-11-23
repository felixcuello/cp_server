# frozen_string_literal: true

class Problem < ApplicationRecord
  belongs_to :contest, optional: true

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

  # Scope: Returns hidden problems
  scope :hidden, -> { where(hidden: true) }

  # Scope: Returns non-hidden problems
  scope :visible, -> { where(hidden: false) }

  # Scope: Returns problems for a specific contest
  scope :for_contest, ->(contest) { where(contest_id: contest.id) }

  # Scope: Returns problems visible to a specific user
  # Visible if: not hidden, OR user is admin, OR (problem belongs to active contest and user is participant)
  scope :visible_to_user, ->(user) {
    if user&.admin?
      # Admins can see all problems (hidden or not)
      all
    else
      # Regular users can see:
      # - Non-hidden problems
      # - Problems in active contests where they are participants
      now = Time.current
      active_contest_ids = Contest.where('start_time <= ? AND end_time >= ?', now, now)
                                   .joins(:contest_participants)
                                   .where(contest_participants: { user_id: user&.id })
                                   .pluck(:id)
      
      where(hidden: false).or(where(contest_id: active_contest_ids))
    end
  }
  
  # Calculate acceptance rate as percentage
  def acceptance_rate
    return 0 if total_submissions.zero?
    ((accepted_submissions.to_f / total_submissions) * 100).round(1)
  end
  
  # Check if user has solved this problem
  def solved_by?(user)
    return false if user.nil?
    user_problem_statuses.where(user: user, status: 'solved').exists?
  end
  
  # Check if user has attempted this problem
  def attempted_by?(user)
    return false if user.nil?
    user_problem_statuses.where(user: user).where.not(status: 'unattempted').exists?
  end
  
  # Update statistics after a submission
  def update_statistics!
    self.total_submissions = submissions.count
    self.accepted_submissions = submissions.where(status: 'accepted').count
    save!
  end
end

