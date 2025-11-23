# frozen_string_literal: true

module ContestAuthorization
  extend ActiveSupport::Concern

  private

  # Before action filter to ensure user can access a contest
  def ensure_contest_access
    @contest = Contest.find(params[:id] || params[:contest_id])
    access_service = ContestAccessService.new(@contest, current_user)

    unless access_service.can_view?
      flash[:alert] = "You do not have access to this contest."
      redirect_to contests_path
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Contest not found."
    redirect_to contests_path
  end

  # Before action filter to ensure user can submit to a contest
  def ensure_contest_participation
    # This assumes the problem or submission has a contest association
    problem = Problem.find_by(id: params[:problem_id] || params[:id])
    
    if problem&.contest
      contest = problem.contest
      access_service = ContestAccessService.new(contest, current_user)

      unless access_service.can_submit?
        flash[:alert] = "You cannot submit to this contest. You must be a participant and the contest must be active."
        redirect_to problem_path(problem)
      end
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Problem not found."
    redirect_to problems_path
  end

  # Before action filter to ensure user can view hidden problems
  # Admins can always view, or if contest is active and user is participant
  def ensure_admin_or_contest_active
    problem_id = params[:id] || params[:problem_id]
    return unless problem_id

    problem = Problem.find_by(id: problem_id)
    # If problem doesn't exist, let the action handle it (will raise RecordNotFound)
    return unless problem

    # Admins can always view
    return if current_user&.admin?

    # If problem is hidden
    if problem.hidden?
      # Check if it belongs to a contest
      if problem.contest
        access_service = ContestAccessService.new(problem.contest, current_user)
        unless access_service.can_view_problem?(problem)
          handle_access_denied
        end
      else
        # Hidden problem not in contest - only admins can see
        handle_access_denied
      end
    end
  rescue ActiveRecord::RecordNotFound
    handle_access_denied
  end

  def handle_access_denied
    respond_to do |format|
      format.html do
        flash[:alert] = "Problem not found."
        redirect_to problems_path
      end
      format.json do
        render json: { submission_id: nil, error: "Problem not found" }, status: :not_found
      end
    end
  end
end
