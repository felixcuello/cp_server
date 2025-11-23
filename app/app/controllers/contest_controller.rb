# frozen_string_literal: true

class ContestController < AuthenticatedController
  before_action :set_contest, except: [:index]
  before_action :check_access, except: [:index, :join]

  def index
    @upcoming_contests = Contest.where('start_time > ?', Time.current).order(:start_time)
    @active_contests = Contest.where('start_time <= ? AND end_time >= ?', Time.current, Time.current).order(:start_time)
    @past_contests = Contest.where('end_time < ?', Time.current).order(start_time: :desc)
  end

  def show
    @access_service = ContestAccessService.new(@contest, current_user)
    @problems = @contest.problems.order(:id)

    # Filter problems based on visibility
    unless current_user.admin?
      @problems = @problems.visible_to_user(current_user)
    end

    @time_remaining = @contest.time_remaining
    @is_participant = @contest.user_participating?(current_user)
  end

  def join
    set_contest
    access_service = ContestAccessService.new(@contest, current_user)

    unless access_service.can_join?
      flash[:alert] = "You cannot join this contest."
      redirect_to contest_path(@contest) and return
    end

    begin
      ContestParticipant.create!(contest: @contest, user: current_user)
      flash[:notice] = "Successfully joined the contest!"
    rescue ActiveRecord::RecordNotUnique
      flash[:alert] = "You are already participating in this contest."
    rescue StandardError => e
      flash[:alert] = "Error joining contest: #{e.message}"
    end

    redirect_to contest_path(@contest)
  end

  def standings
    @access_service = ContestAccessService.new(@contest, current_user)

    unless @access_service.can_view_standings?
      flash[:alert] = "You cannot view standings for this contest."
      redirect_to contest_path(@contest) and return
    end

    @standings_service = ContestStandingsService.new(@contest)
    @standings = @standings_service.calculate_standings_with_rank
  end

  def submissions
    @access_service = ContestAccessService.new(@contest, current_user)

    # Users can only see their own submissions unless they're admin
    if current_user.admin?
      @submissions = @contest.submissions.includes(:user, :problem, :programming_language)
                             .order(created_at: :desc)

      # Filter by user if specified
      if params[:user_id].present?
        @submissions = @submissions.where(user_id: params[:user_id])
      end
    else
      @submissions = @contest.submissions.where(user: current_user)
                             .includes(:problem, :programming_language)
                             .order(created_at: :desc)
    end

    # Filter by problem if specified
    if params[:problem_id].present?
      @submissions = @submissions.where(problem_id: params[:problem_id])
    end

    # Filter by status if specified
    if params[:status].present? && params[:status] != 'all'
      @submissions = @submissions.where(status: params[:status])
    end
  end

  private

  def set_contest
    @contest = Contest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Contest not found."
    redirect_to contests_path
  end

  def check_access
    access_service = ContestAccessService.new(@contest, current_user)

    unless access_service.can_view?
      flash[:alert] = "You do not have access to this contest."
      redirect_to contests_path
    end
  end
end
