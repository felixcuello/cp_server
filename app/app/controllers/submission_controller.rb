# frozen_string_literal: true

require 'open3'

class SubmissionController < AuthenticatedController
  include ContestAuthorization
  def index
    @submissions = Submission.includes(:user, :problem, :programming_language, :contest)
                             .order(created_at: :desc)

    # Filter by contest if specified
    if params[:contest_id].present? && params[:contest_id] != 'all'
      @submissions = @submissions.where(contest_id: params[:contest_id])
      @contest = Contest.find_by(id: params[:contest_id])
    end

    # By default, show only current user's submissions
    # Unless "show_all" is enabled
    @show_all = params[:show_all] == 'true'
    unless @show_all
      @submissions = @submissions.where(user: current_user)
    end

    # Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @total_count = @submissions.count
    @total_pages = (@total_count / @per_page.to_f).ceil

    @submissions = @submissions.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def contest_submissions
    @contest = Contest.find(params[:contest_id])
    access_service = ContestAccessService.new(@contest, current_user)

    unless access_service.can_view_standings?
      flash[:alert] = "You cannot view submissions for this contest."
      redirect_to contests_path and return
    end

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

    # Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @total_count = @submissions.count
    @total_pages = (@total_count / @per_page.to_f).ceil

    @submissions = @submissions.offset((@page - 1) * @per_page).limit(@per_page)
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Contest not found."
    redirect_to contests_path
  end

  def show
    begin
      @submission = Submission.includes(:user, :problem, :programming_language).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html {
          redirect_to submission_path, alert: "Submission not found."
        }
        format.json {
          render json: { error: 'Submission not found' }, status: :not_found
        }
      end
      return
    end

    # Security check: only allow users to view their own submissions, or admins to view any
    if @submission.user_id != current_user.id && !current_user.admin?
      respond_to do |format|
        format.html {
          redirect_to submission_path, alert: "You don't have permission to view this submission."
        }
        format.json {
          render json: { error: 'Unauthorized' }, status: :forbidden
        }
      end
      return
    end

    # For admin view: get the failed example if submission failed
    @failed_example = nil
    if current_user&.admin? && @submission.user_output.present?
      # Parse example number from status (e.g., "wrong answer (example 1)")
      example_match = @submission.status.match(/example (\d+)/i)
      if example_match
        example_index = example_match[1].to_i - 1 # Convert to 0-based index
        examples = @submission.problem.examples.order(:id)
        @failed_example = examples[example_index] if example_index >= 0 && example_index < examples.count
      elsif @submission.status.downcase.include?("presentation error") || @submission.status.downcase.include?("wrong answer")
        # For presentation error or wrong answer without example number, try to find the failed example
        # by checking which example's expected output doesn't match the user output
        examples = @submission.problem.examples.order(:id)
        examples.each do |example|
          if example.output.present? && @submission.user_output.present?
            # Simple check: if outputs are different, this might be the failed example
            normalized_expected = example.output.strip.gsub(/\s+/, " ")
            normalized_user = @submission.user_output.strip.gsub(/\s+/, " ")
            if normalized_expected != normalized_user
              @failed_example = example
              break
            end
          end
        end
        # If we couldn't find a match, use the first example as fallback
        @failed_example ||= examples.first if examples.any?
      end
    end

    respond_to do |format|
      format.html # renders the HTML view
      format.json {
        render json: {
          id: @submission.id,
          source_code: @submission.source_code,
          language_id: @submission.programming_language_id,
          status: @submission.status,
          time_used: @submission.time_used,
          memory_used: @submission.memory_used,
          created_at: @submission.created_at
        }
      }
    end
  end

  def submit
    submission = submission_successful?
    if submission
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Your solution was submitted successfully!" }
        format.html { redirect_to problems_path, notice: "Your solution was submitted successfully!" }
        format.json {
          render json: {
            success: true,
            message: "Submission successful",
            submission_id: submission.id,
            status: submission.status
          }
        }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:alert] = "There was an error submitting your solution." }
        format.html { redirect_to problems_path, alert: "There was an error submitting your solution." }
        format.json { render json: { success: false, message: "Submission failed", status: "error" }, status: :unprocessable_entity }
      end
    end

    @submissions = Submission.all
  end

  def test
    Rails.logger.info "=== TEST ACTION CALLED ==="
    Rails.logger.info "Problem ID: #{params[:problem_id]}"
    Rails.logger.info "Language ID: #{params[:programming_language_id]}"
    Rails.logger.info "Source code present: #{params[:source_code].present?}"

    result = test_code

    Rails.logger.info "Test result: #{result.inspect}"

    respond_to do |format|
      format.json { render json: result }
    end
  rescue StandardError => e
    Rails.logger.error "Error in test action: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: 500 }
    end
  end

  private

  # Strong parameters for submission creation
  # Only permits the specific parameters we need, preventing mass assignment attacks
  def submission_params
    # Handle file upload for source_code
    source_code_content = if params[:source_code].respond_to?(:read)
                            params[:source_code].read
                          else
                            params[:source_code]
                          end

    {
      problem_id: params[:problem_id]&.to_i,
      programming_language_id: params[:programming_language_id]&.to_i,
      source_code: source_code_content
    }
  end

  # Strong parameters for test endpoint
  def test_params
    # Handle file upload for source_code
    source_code_content = if params[:source_code].respond_to?(:read)
                            params[:source_code].read
                          else
                            params[:source_code]
                          end

    {
      problem_id: params[:problem_id]&.to_i,
      programming_language_id: params[:programming_language_id]&.to_i,
      source_code: source_code_content
    }
  end

  def submission_successful?
    # Always use current_user - never trust user_id from params
    submission_params_hash = submission_params

    # Validate required parameters
    unless submission_params_hash[:problem_id].present? &&
           submission_params_hash[:programming_language_id].present? &&
           submission_params_hash[:source_code].present?
      Rails.logger.error("Submission failed: Missing required parameters")
      return nil
    end

    # Find the problem
    problem = Problem.find_by(id: submission_params_hash[:problem_id])
    unless problem
      Rails.logger.error("Submission failed: Problem not found")
      return nil
    end

    # Check if problem belongs to a contest
    if problem.contest
      contest = problem.contest
      access_service = ContestAccessService.new(contest, current_user)

      # Verify user can submit to this contest
      unless access_service.can_submit?
        Rails.logger.error("Submission failed: User cannot submit to this contest")
        return nil
      end

      # Set contest_id explicitly (also set by before_save callback, but explicit is clearer)
      contest_id = contest.id
    else
      contest_id = nil
    end

    submission = Submission.create!(
      problem_id: submission_params_hash[:problem_id],
      programming_language_id: submission_params_hash[:programming_language_id],
      user: current_user,  # Explicitly set to current_user, ignoring any user_id in params
      source_code: submission_params_hash[:source_code],
      contest_id: contest_id,
      status: "queued"
    )

    SubmissionJob.perform_async(submission.id)

    submission
  rescue StandardError => e
    Rails.logger.error("Submission failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  def test_code
    begin
      Rails.logger.info "=== TEST_CODE METHOD CALLED ==="

      test_params_hash = test_params

      # Validate required parameters
      unless test_params_hash[:problem_id].present? &&
             test_params_hash[:programming_language_id].present? &&
             test_params_hash[:source_code].present?
        return {
          success: false,
          error: "Missing required parameters: problem_id, programming_language_id, or source_code"
        }
      end

      problem = Problem.find(test_params_hash[:problem_id])
      Rails.logger.info "Problem found: #{problem.title}"

      language = ProgrammingLanguage.find(test_params_hash[:programming_language_id])
      Rails.logger.info "Language found: #{language.name}"

      source_code = test_params_hash[:source_code]
      Rails.logger.info "Source code length: #{source_code.length}"

      # Get visible examples only
      examples = problem.examples.where(is_hidden: false).order(:id)
      Rails.logger.info "Found #{examples.count} visible examples"

      if examples.empty?
        return {
          success: false,
          error: "No test cases available for this problem"
        }
      end

      # Run code against each visible example
      results = []
      overall_status = "passed"

      examples.each_with_index do |example, index|
        Rails.logger.info "Running test #{index + 1}..."
        result = run_single_test(source_code, language, example, problem)
        Rails.logger.info "Test #{index + 1} result: #{result[:status]}"

        results << {
          example_number: index + 1,
          input: example.input,
          expected_output: example.output,
          actual_output: result[:output],
          status: result[:status],
          runtime: result[:runtime],
          error_message: result[:error_message]
        }

        overall_status = "failed" if result[:status] != "passed"
      end

      Rails.logger.info "Overall status: #{overall_status}"

      {
        success: true,
        overall_status: overall_status,
        test_results: results
      }
    rescue StandardError => e
      Rails.logger.error "Error in test_code: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: "Error running tests: #{e.message}"
      }
    end
  end

  def run_single_test(source_code, language, example, problem)
    service = SubmissionService.new(
      source_code: source_code,
      language: language,
      example: example,
      problem: problem
    )
    service.execute
  rescue SubmissionService::CompilationError => e
    {
      status: "compilation_error",
      output: "",
      runtime: 0,
      error_message: "Compilation failed:\n#{e.message}"
    }
  rescue StandardError => e
    Rails.logger.error "Error in run_single_test: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    {
      status: "error",
      output: "",
      runtime: 0,
      error_message: "System error: #{e.message}"
    }
  end
end
