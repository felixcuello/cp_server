# frozen_string_literal: true

class ContestParticipant < ApplicationRecord
  belongs_to :contest
  belongs_to :user

  validates :contest_id, uniqueness: { scope: :user_id, message: "user is already participating in this contest" }

  # Set joined_at timestamp when creating a new participation
  before_create :set_joined_at

  # Calculate number of problems solved by this user in the contest
  def problems_solved
    return 0 if contest.nil? || user.nil?
    
    contest.problems.joins(:user_problem_statuses)
          .where(user_problem_statuses: { user_id: user.id, status: 'solved' })
          .count
  end

  # Calculate total time taken (in minutes) including penalties
  # For each solved problem: time_to_solve + (penalty_minutes * incorrect_attempts)
  def total_time_minutes
    return 0 if contest.nil? || user.nil?

    total_time = 0
    contest_start_time = contest.start_time

    contest.problems.each do |problem|
      # Find the first accepted submission for this problem by this user
      first_accepted = problem.submissions
                              .where(user: user, status: Submission::ACCEPTED)
                              .where('created_at >= ?', contest_start_time)
                              .order(:created_at)
                              .first

      next unless first_accepted

      # Calculate time to solve (minutes from contest start to first accepted)
      time_to_solve = ((first_accepted.created_at - contest_start_time) / 60).to_i

      # Count incorrect attempts before the first accepted submission
      incorrect_attempts = problem.submissions
                                  .where(user: user)
                                  .where('created_at >= ? AND created_at < ?', contest_start_time, first_accepted.created_at)
                                  .where.not(status: Submission::ACCEPTED)
                                  .count

      # Add time to solve + penalties
      total_time += time_to_solve + (contest.penalty_minutes * incorrect_attempts)
    end

    total_time
  end

  # Calculate total number of incorrect submissions (for penalty calculation)
  def total_penalties
    return 0 if contest.nil? || user.nil?

    total_penalties = 0
    contest_start_time = contest.start_time

    contest.problems.each do |problem|
      # Find the first accepted submission for this problem by this user
      first_accepted = problem.submissions
                              .where(user: user, status: Submission::ACCEPTED)
                              .where('created_at >= ?', contest_start_time)
                              .order(:created_at)
                              .first

      next unless first_accepted

      # Count incorrect attempts before the first accepted submission
      incorrect_attempts = problem.submissions
                                  .where(user: user)
                                  .where('created_at >= ? AND created_at < ?', contest_start_time, first_accepted.created_at)
                                  .where.not(status: Submission::ACCEPTED)
                                  .count

      total_penalties += incorrect_attempts
    end

    total_penalties
  end

  # Get detailed statistics per problem
  def problem_statistics
    return [] if contest.nil? || user.nil?

    stats = []
    contest_start_time = contest.start_time

    contest.problems.each do |problem|
      first_accepted = problem.submissions
                              .where(user: user, status: Submission::ACCEPTED)
                              .where('created_at >= ?', contest_start_time)
                              .order(:created_at)
                              .first

      incorrect_attempts = if first_accepted
                            problem.submissions
                                   .where(user: user)
                                   .where('created_at >= ? AND created_at < ?', contest_start_time, first_accepted.created_at)
                                   .where.not(status: Submission::ACCEPTED)
                                   .count
                          else
                            problem.submissions
                                   .where(user: user)
                                   .where('created_at >= ?', contest_start_time)
                                   .where.not(status: Submission::ACCEPTED)
                                   .count
                          end

      time_to_solve = if first_accepted
                       ((first_accepted.created_at - contest_start_time) / 60).to_i
                     else
                       nil
                     end

      stats << {
        problem: problem,
        solved: first_accepted.present?,
        time_to_solve: time_to_solve,
        incorrect_attempts: incorrect_attempts,
        total_time: first_accepted ? time_to_solve + (contest.penalty_minutes * incorrect_attempts) : nil
      }
    end

    stats
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
