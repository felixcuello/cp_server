# frozen_string_literal: true

class SubmissionController < ApplicationController
  def index
    @submissions = Submission.includes(:user, :problem, :programming_language)
                             .order(created_at: :desc)
    
    # Filter by status
    if params[:status].present? && params[:status] != 'all'
      @submissions = @submissions.where(status: params[:status])
    end
    
    # Filter by language
    if params[:language].present? && params[:language] != 'all'
      @submissions = @submissions.where(programming_language_id: params[:language])
    end
    
    # Filter by problem
    if params[:problem].present? && params[:problem] != 'all'
      @submissions = @submissions.where(problem_id: params[:problem])
    end
    
    # Filter by user (my submissions only)
    if params[:my_submissions] == 'true' && current_user
      @submissions = @submissions.where(user: current_user)
    end
    
    # Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @total_count = @submissions.count
    @total_pages = (@total_count / @per_page.to_f).ceil
    
    @submissions = @submissions.offset((@page - 1) * @per_page).limit(@per_page)
    
    # For filters
    @all_languages = ProgrammingLanguage.order(:name)
    @all_problems = Problem.order(:id)
    @statuses = [
      Submission::ACCEPTED,
      Submission::WRONG_ANSWER,
      Submission::TIME_LIMIT_EXCEEDED,
      Submission::RUNTIME_ERROR,
      Submission::COMPILATION_ERROR,
      Submission::MEMORY_LIMIT_EXCEEDED,
      Submission::PRESENTATION_ERROR,
      Submission::RUNNING,
      Submission::ENQUEUED
    ].uniq
  end
  
  def show
    @submission = Submission.includes(:user, :problem, :programming_language).find(params[:id])
  end

  def submit
    if submission_successful?
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Your solution was submitted successfully!" }
        format.html { redirect_to problems_path, notice: "Your solution was submitted successfully!" }
        format.json { render json: { success: true, message: "Submission successful" } }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:alert] = "There was an error submitting your solution." }
        format.html { redirect_to problems_path, alert: "There was an error submitting your solution." }
        format.json { render json: { success: false, message: "Submission failed" }, status: :unprocessable_entity }
      end
    end

    @submissions = Submission.all
  end

  private

  def submission_successful?
    submission = Submission.create!(
      problem_id: params[:problem_id],
      programming_language_id: params[:programming_language_id],
      user: current_user,
      source_code: params[:source_code].read,
      status: "queued"
    )

    SubmissionJob.perform_async(submission.id)

    true
  rescue StandardError
    false
  end
end
