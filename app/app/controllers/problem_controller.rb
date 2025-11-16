# frozen_string_literal: true

class ProblemController < AuthenticatedController
  before_action :difficulty, only: %i[index]

  def index
    @problems = Problem.includes(:tags, :user_problem_statuses)
    
    # Filter by difficulty
    if params[:difficulty]
      @problems = @problems.where(difficulty: @difficulty)
    end
    
    # Filter by tag
    if params[:tag]
      @problems = @problems.where(tags: { name: params[:tag] })
    end
    
    # Filter by status
    if params[:status] && current_user
      case params[:status]
      when 'solved'
        @problems = @problems.joins(:user_problem_statuses)
                            .where(user_problem_statuses: { user_id: current_user.id, status: 'solved' })
      when 'attempted'
        @problems = @problems.joins(:user_problem_statuses)
                            .where(user_problem_statuses: { user_id: current_user.id })
                            .where.not(user_problem_statuses: { status: 'solved' })
      when 'unsolved'
        solved_ids = UserProblemStatus.where(user_id: current_user.id, status: 'solved').pluck(:problem_id)
        @problems = @problems.where.not(id: solved_ids)
      end
    end
    
    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @problems = @problems.where("title LIKE ? OR id = ?", search_term, params[:search].to_i)
    end
    
    # Sorting
    case params[:sort]
    when 'acceptance_asc'
      @problems = @problems.order(Arel.sql('CAST(accepted_submissions AS FLOAT) / NULLIF(total_submissions, 0) ASC'))
    when 'acceptance_desc'
      @problems = @problems.order(Arel.sql('CAST(accepted_submissions AS FLOAT) / NULLIF(total_submissions, 0) DESC'))
    when 'difficulty_asc'
      @problems = @problems.order(difficulty: :asc)
    when 'difficulty_desc'
      @problems = @problems.order(difficulty: :desc)
    when 'title'
      @problems = @problems.order(title: :asc)
    else
      @problems = @problems.order(id: :asc)
    end
    
    # Pagination would go here (for now, limit to 100)
    @problems = @problems.limit(100)
    
    # Get all tags for filter
    @all_tags = Tag.order(:name)
  end

  def show
    @problem = Problem.find(params[:id])
    @languages = ProgrammingLanguage.order(:name)
    
    # Get user's status for this problem
    if current_user
      @user_status = UserProblemStatus.find_by(user: current_user, problem: @problem)
      
      # Get user's submission history for this problem
      @user_submissions = Submission.where(user: current_user, problem: @problem)
                                    .order(created_at: :desc)
                                    .limit(10)
      
      # Get best submission
      @best_submission = Submission.where(user: current_user, problem: @problem, status: 'accepted')
                                   .order(time_used: :asc)
                                   .first
    end
    
    # Get problem statistics
    @total_submissions = @problem.total_submissions
    @total_accepted = @problem.accepted_submissions
    @acceptance_rate = @problem.acceptance_rate
    
    # Get similar problems (same tags, similar difficulty)
    @similar_problems = Problem.joins(:tags)
                               .where(tags: { id: @problem.tags.pluck(:id) })
                               .where.not(id: @problem.id)
                               .where(difficulty: @problem.difficulty)
                               .distinct
                               .limit(5)
  end

  private

  def difficulty
    @difficulty = params[:difficulty].to_sym if params[:difficulty]
  end
end
