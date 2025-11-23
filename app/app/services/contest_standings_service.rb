# frozen_string_literal: true

class ContestStandingsService
  def initialize(contest)
    @contest = contest
  end

  # Calculate and return sorted standings for all participants
  # Returns array of hashes with participant information and statistics
  def calculate_standings
    standings = []

    @contest.contest_participants.includes(:user).each do |participant|
      user = participant.user
      problems_solved = participant.problems_solved
      total_time = participant.total_time_minutes
      problem_stats = participant.problem_statistics

      standings << {
        user: user,
        user_alias: user.alias,
        user_name: "#{user.first_name} #{user.last_name}",
        problems_solved: problems_solved,
        total_time: total_time,
        problem_details: problem_stats
      }
    end

    # Sort standings:
    # 1. By number of problems solved (descending - more is better)
    # 2. By total time (ascending - lower is better)
    standings.sort_by do |standing|
      [-standing[:problems_solved], standing[:total_time]]
    end
  end

  # Get standings with rank numbers
  def calculate_standings_with_rank
    standings = calculate_standings
    current_rank = 1
    previous_problems = nil
    previous_time = nil

    standings.map do |standing|
      # If this participant has different stats than previous, increment rank
      if previous_problems != standing[:problems_solved] || previous_time != standing[:total_time]
        current_rank = standings.index(standing) + 1
        previous_problems = standing[:problems_solved]
        previous_time = standing[:total_time]
      end

      standing.merge(rank: current_rank)
    end
  end
end
