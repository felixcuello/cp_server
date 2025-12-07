# frozen_string_literal: true

class Problem < ApplicationRecord
  belongs_to :contest, optional: true

  has_many :examples
  has_many :problem_tags
  has_many :tags, through: :problem_tags
  has_many :constraints
  has_many :submissions
  has_many :user_problem_statuses
  has_many :problem_templates, dependent: :destroy
  has_many :problem_testers, dependent: :destroy

  enum :difficulty, {
    easy: 0,
    medium: 1,
    hard: 2
  }

  enum :testing_mode, {
    stdin_stdout: 'stdin_stdout',
    function: 'function'
  }, prefix: true, default: 'stdin_stdout'

  # Scope: Returns hidden problems
  scope :hidden, -> { where(hidden: true) }

  # Scope: Returns non-hidden problems
  scope :visible, -> { where(hidden: false) }

  # Scope: Returns problems for a specific contest
  scope :for_contest, ->(contest) { where(contest_id: contest.id) }

  # Scope: Returns STDIN/STDOUT mode problems
  scope :stdin_stdout_mode, -> { where(testing_mode: 'stdin_stdout') }

  # Scope: Returns function-based mode problems
  scope :function_mode, -> { where(testing_mode: 'function') }

  # Scope: Returns problems visible to a specific user
  # Visible if:
  # - User is admin (sees all)
  # - Non-hidden problems that are NOT in a contest OR contest has ended
  # - Problems in active contests where user is participant
  scope :visible_to_user, ->(user) {
    if user&.admin?
      # Admins can see all problems (hidden or not)
      all
    else
      # Regular users can see:
      # 1. Non-hidden problems that are NOT in contests
      # 2. Non-hidden problems in ENDED contests
      # 3. Problems in ACTIVE contests where they are participants
      now = Time.current

      # Active contests where user is a participant
      active_contest_ids = Contest.where('start_time <= ? AND end_time >= ?', now, now)
                                   .joins(:contest_participants)
                                   .where(contest_participants: { user_id: user&.id })
                                   .pluck(:id)

      # Ended contests (problems become public)
      ended_contest_ids = Contest.where('end_time < ?', now).pluck(:id)

      # Combine conditions:
      # - Not hidden AND (no contest OR contest has ended)
      # - OR in an active contest where user participates
      where(hidden: false, contest_id: nil)
        .or(where(hidden: false, contest_id: ended_contest_ids))
        .or(where(contest_id: active_contest_ids))
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

  # Get template for a specific programming language
  def template_for(language)
    problem_templates.find_by(programming_language: language)
  end

  # Get tester for a specific programming language
  def tester_for(language)
    problem_testers.find_by(programming_language: language)
  end

  # Check if problem uses function-based testing
  def function_based?
    testing_mode == 'function'
  end

  # Check if problem uses stdin/stdout testing
  def stdin_stdout_based?
    testing_mode == 'stdin_stdout'
  end

  # Get available languages for function-based problems
  # Only returns languages that have both template and tester
  def available_languages_for_function_mode
    return ProgrammingLanguage.all unless function_based?

    template_language_ids = problem_templates.pluck(:programming_language_id)
    tester_language_ids = problem_testers.pluck(:programming_language_id)
    available_language_ids = template_language_ids & tester_language_ids

    ProgrammingLanguage.where(id: available_language_ids)
  end
end

