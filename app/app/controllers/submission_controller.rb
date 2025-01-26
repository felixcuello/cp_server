# frozen_string_literal: true

class SubmissionController < ApplicationController
  def index
    @submissions = Submission.all
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
