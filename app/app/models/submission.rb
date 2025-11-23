# frozen_string_literal: true

require 'open3'

class Submission < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language
  belongs_to :user
  belongs_to :contest, optional: true

  validates :source_code, presence: true, length: { maximum: 1_000_000 } # 1MB limit
  validates :status, presence: true
  validates :problem, presence: true
  validates :programming_language, presence: true
  validate :problem_exists
  validate :programming_language_exists
  validate :user_can_submit_to_problem, on: :create

  # Security: Ensure user_id cannot be set to a different user than the user association
  # This prevents mass assignment attacks where someone tries to submit as another user
  before_validation :ensure_user_id_matches_user_association, on: :create
  before_save :prevent_user_id_change, if: :persisted?
  before_save :set_contest_id_from_problem

  # Scope: Returns submissions for a specific contest
  scope :for_contest, ->(contest) { where(contest_id: contest.id) }

  # Scope: Returns submissions that are part of a contest
  scope :contest_submissions, -> { where.not(contest_id: nil) }

  # Scope: Returns submissions not part of a contest
  scope :regular_submissions, -> { where(contest_id: nil) }

  # Update problem statistics after submission status changes
  after_save :update_problem_statistics, if: :saved_change_to_status?
  after_save :update_user_problem_status, if: :saved_change_to_status?

  DEBUG = false
  ACCEPTED = "accepted"
  COMPILATION_ERROR = "compilation error"
  COMPILING = "compiling"
  MEMORY_LIMIT_EXCEEDED = "memory limit exceeded"
  PRESENTATION_ERROR = "presentation error"
  RUNNING = "running"
  RUNTIME_ERROR = "runtime error"
  TIME_LIMIT_EXCEEDED = "time limit exceeded"
  WRONG_ANSWER = "wrong answer"
  ENQUEUED = "enqueued"

  def run!
    self.update!(status: ENQUEUED)

    if self.programming_language.compiler_binary != ""
      run_with_compiler!
    else
      run_with_interpreter!
    end
  end

  def run_with_interpreter!
    problem = Problem.find self.problem_id
    start_time = Time.now

    final_status = ACCEPTED

    self.update!(status: RUNNING)
    problem.examples.order(:id).each_with_index do |example, index|
      # Use SubmissionService to run the test
      service = SubmissionService.new(
        source_code: self.source_code,
        language: self.programming_language,
        example: example,
        problem: problem
      )

      result = service.execute
      debug!("#{__LINE__} Test #{index + 1} result: #{result[:status]}")

      # Map service result status to Submission status constants
      case result[:status]
      when "time_limit_exceeded"
        final_status = TIME_LIMIT_EXCEEDED
      when "memory_limit_exceeded"
        final_status = MEMORY_LIMIT_EXCEEDED
      when "runtime_error"
        final_status = RUNTIME_ERROR
      when "compilation_error"
        final_status = COMPILATION_ERROR
      when "passed"
        # Continue to next example
        next
      when "presentation_error"
        final_status = PRESENTATION_ERROR
      when "wrong_answer"
        final_status = WRONG_ANSWER + " (example #{index + 1})"
      else
        final_status = RUNTIME_ERROR
      end

      # Break if we already have a non-accepted status
      break if final_status != ACCEPTED
    end

    time_used = Time.now - start_time
    self.update!(time_used: time_used)
    self.update!(status: final_status)
  end

  def run_with_compiler!
    problem = Problem.find self.problem_id
    start_time = Time.now

    self.update!(status: COMPILING)

    # Try to compile - if compilation fails, TestExecutionService will handle it
    # We run the first test to trigger compilation and catch compilation errors early
    first_example = problem.examples.order(:id).first
    if first_example.nil?
      self.update!(status: RUNTIME_ERROR)
      return
    end

    service = SubmissionService.new(
      source_code: self.source_code,
      language: self.programming_language,
      example: first_example,
      problem: problem
    )

    begin
      first_result = service.execute
    rescue SubmissionService::CompilationError => e
      self.update!(status: COMPILATION_ERROR)
      return
    end

    # If compilation succeeded, continue with all examples
    final_status = ACCEPTED

    self.update!(status: RUNNING)

    problem.examples.order(:id).each_with_index do |example, index|
      # Skip first example if we already ran it (unless it failed)
      if index == 0 && first_result[:status] == "passed"
        next
      elsif index == 0
        result = first_result
      else
        # Use SubmissionService to run the test
        service = SubmissionService.new(
          source_code: self.source_code,
          language: self.programming_language,
          example: example,
          problem: problem
        )

        result = service.execute
      end

      debug!("#{__LINE__} Test #{index + 1} result: #{result[:status]}")

      # Map service result status to Submission status constants
      case result[:status]
      when "time_limit_exceeded"
        final_status = TIME_LIMIT_EXCEEDED
      when "memory_limit_exceeded"
        final_status = MEMORY_LIMIT_EXCEEDED
      when "runtime_error"
        final_status = RUNTIME_ERROR
      when "compilation_error"
        final_status = COMPILATION_ERROR
      when "passed"
        # Continue to next example
        next
      when "presentation_error"
        final_status = PRESENTATION_ERROR
      when "wrong_answer"
        final_status = WRONG_ANSWER + " (example #{index + 1})"
      else
        final_status = RUNTIME_ERROR
      end

      # Break if we already have a non-accepted status
      break if final_status != ACCEPTED
    end

    time_used = Time.now - start_time
    self.update!(time_used: time_used)
    self.update!(status: final_status)
  end

  private

  # Validation: Ensure problem exists
  def problem_exists
    return if problem_id.blank?

    unless Problem.exists?(problem_id)
      errors.add(:problem, "does not exist")
    end
  end

  # Validation: Ensure programming language exists
  def programming_language_exists
    return if programming_language_id.blank?

    unless ProgrammingLanguage.exists?(programming_language_id)
      errors.add(:programming_language, "does not exist")
    end
  end

  # Validation: Ensure user has permission to submit to problem
  # For now, all authenticated users can submit to all problems
  # This can be extended later to check for hidden problems, contest restrictions, etc.
  def user_can_submit_to_problem
    return if user.blank? || problem.blank?

    # Add any permission checks here in the future
    # For example: check if problem is hidden, check contest restrictions, etc.
    # if problem.hidden? && !user.admin?
    #   errors.add(:problem, "is not available for submission")
    # end
  end

  # Security: Ensure that if user_id is set directly, it matches the user association
  # This prevents users from submitting as other users
  def ensure_user_id_matches_user_association
    if user.present?
      # Always use the user association to set user_id - ignore any user_id that was set directly
      self.user_id = user.id
    end
  end

  # Security: Prevent changing user_id after submission is created
  # This ensures a submission always belongs to the user who created it
  def prevent_user_id_change
    if user_id_changed? && persisted?
      self.user_id = user_id_was
      Rails.logger.warn("Attempted to change user_id on submission #{id} from #{user_id_was} to #{user_id}. Blocked.")
      errors.add(:user_id, "cannot be changed after submission is created")
    end
  end

  # Automatically set contest_id from problem if not already set
  def set_contest_id_from_problem
    if contest_id.nil? && problem.present? && problem.contest_id.present?
      self.contest_id = problem.contest_id
    end
  end

  def debug!(message)
    File.write("/tmp/debug", "#{message}\n", mode: 'a') if DEBUG
  end

  def update_problem_statistics
    problem.update_statistics!
  end

  def update_user_problem_status
    # Use database-level locking to prevent race conditions with concurrent submissions
    # The unique constraint on [user_id, problem_id] ensures only one record exists
    # This implementation uses blocking locks - the second user will wait for the first to finish
    UserProblemStatus.transaction(requires_new: true) do
      # First, try to find the record with a lock (this will wait if another transaction has it locked)
      # If not found, create it within the same transaction
      user_status = UserProblemStatus.where(user: user, problem: problem).lock.first

      if user_status.nil?
        # Record doesn't exist, create it with initial values
        # The unique constraint will prevent duplicates if two processes try simultaneously
        begin
          user_status = UserProblemStatus.create!(
            user: user,
            problem: problem,
            status: 'attempted',
            attempts: 0
          )
        rescue ActiveRecord::RecordNotUnique
          # Another process created it between our check and create, fetch it with lock
          user_status = UserProblemStatus.where(user: user, problem: problem).lock.first
        end
      end

      # At this point, we have the record with an exclusive lock
      # Other processes will wait here until we release the lock (end of transaction)

      # If this submission is accepted, mark as solved
      if status == ACCEPTED
        user_status.status = 'solved'
        user_status.first_solved_at ||= Time.current
        user_status.save!
      # Otherwise, if not already solved, mark as attempted and increment attempts
      elsif user_status.status != 'solved'
        user_status.status = 'attempted'
        user_status.attempts = (user_status.attempts || 0) + 1
        user_status.save!
      end
    end
    # Transaction commits here, releasing the lock so the next waiting process can proceed
  end
end
