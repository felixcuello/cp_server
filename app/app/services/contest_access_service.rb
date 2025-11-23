# frozen_string_literal: true

class ContestAccessService
  def initialize(contest, user)
    @contest = contest
    @user = user
  end

  # Can user view the contest page?
  # - Admins can always view
  # - Anyone can view contest info (before/during/after)
  # - More detailed access (problems, standings) is controlled by other methods
  def can_view?
    return false if @user.nil?
    return true if @user.admin?
    true # Anyone can view contest page (to see info, join button, etc.)
  end

  # Can user join the contest?
  # - Admins can always join
  # - User must not already be participating
  # - Contest must not have ended
  def can_join?
    return false if @user.nil?
    return true if @user.admin? # Admins can join any contest
    return false if @contest.ended? # Cannot join after contest ends
    return false if @contest.user_participating?(@user) # Already participating

    true
  end

  # Can user submit solutions to contest problems?
  # - Admins can always submit
  # - User must be a participant
  # - Contest must be active (not ended, not upcoming)
  def can_submit?
    return false if @user.nil?
    return true if @user.admin? # Admins can always submit
    return false unless @contest.user_participating?(@user) # Must be participant
    return false if @contest.upcoming? # Cannot submit before contest starts
    return false if @contest.ended? # Cannot submit after contest ends

    @contest.active?
  end

  # Can user view a specific problem in the contest?
  # - Admins can always view
  # - If problem is hidden and contest hasn't started, only admin
  # - If contest is active/ended and user is participant, can view
  # - If problem is not hidden, anyone can view (regular problem)
  def can_view_problem?(problem)
    return false if @user.nil? || problem.nil?
    return true if @user.admin? # Admins can view all problems

    # If problem is not part of this contest, use regular visibility rules
    if problem.contest_id != @contest.id
      return !problem.hidden? || @user.admin?
    end

    # Problem belongs to this contest
    if problem.hidden?
      # Hidden problems: only visible if contest is active/ended and user is participant
      return false if @contest.upcoming? # Hidden until contest starts
      return @contest.user_participating?(@user) if @contest.active? || @contest.ended?
      return false
    else
      # Non-hidden problems: visible to participants during/after contest
      return true if @contest.user_participating?(@user) && (@contest.active? || @contest.ended?)
      return true if @contest.ended? # After contest ends, problems become public
      return false
    end
  end

  # Can user view contest standings?
  # - Admins can always view
  # - Anyone can view standings after contest starts (or maybe only participants?)
  # - For now, allow anyone to view standings once contest has started
  def can_view_standings?
    return false if @user.nil?
    return true if @user.admin?
    return true if @contest.active? || @contest.ended? # Can view during and after contest
    false # Cannot view standings before contest starts
  end
end
