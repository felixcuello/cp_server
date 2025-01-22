# frozen_string_literal: true

class ProblemController < AuthenticatedController
  before_action :difficulty, only: %i[index]

  def index
    @problems = Problem.includes(:tags)

    if params[:tag]
      @problems = @problems.where(tags: { name: params[:tag] })
    elsif params[:difficulty]
      @problems = @problems.where(difficulty: @difficulty)
    end
  end

  def show
    @problem = Problem.find(params[:id])
    @languages = ProgrammingLanguage.all
  end

  def submit
    if submission_successful?
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Your solution was submitted successfully!" }
        format.html { redirect_to problems_path, notice: "Your solution was submitted successfully!" }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:alert] = "There was an error submitting your solution." }
        format.html { redirect_to problems_path, alert: "There was an error submitting your solution." }
      end
    end
  end

  private

  def difficulty
    @difficulty = params[:difficulty].to_sym if params[:difficulty]
  end

  def submission_successful?
    Submission.create!(
      problem_id: params[:problem_id],
      programming_language_id: params[:programming_language_id],
      user: current_user,
      source_code: params[:source_code].read,
      status: :queued
    )

    true
  rescue StandardError
    false
  end
end
