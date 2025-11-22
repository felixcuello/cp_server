# frozen_string_literal: true

require 'open3'

class SubmissionController < AuthenticatedController
  def index
    @submissions = Submission.includes(:user, :problem, :programming_language)
                             .order(created_at: :desc)
    
    # By default, show only current user's submissions
    # Unless "show_all" is enabled
    @show_all = params[:show_all] == 'true'
    unless @show_all
      @submissions = @submissions.where(user: current_user)
    end
    
    # Filter by specific user (when showing all)
    if params[:user_id].present? && params[:user_id] != 'all' && @show_all
      @submissions = @submissions.where(user_id: params[:user_id])
    end
    
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
    
    # Filter by time range
    if params[:time_range].present? && params[:time_range] != 'all'
      case params[:time_range]
      when 'today'
        @submissions = @submissions.where('created_at >= ?', Time.zone.now.beginning_of_day)
      when 'week'
        @submissions = @submissions.where('created_at >= ?', 1.week.ago)
      when 'month'
        @submissions = @submissions.where('created_at >= ?', 1.month.ago)
      end
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
    @all_users = User.order(:alias) if @show_all
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
    
    # Security check: only allow users to view their own submissions
    if @submission.user_id != current_user.id
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
    
    submission = Submission.create!(
      problem_id: submission_params_hash[:problem_id],
      programming_language_id: submission_params_hash[:programming_language_id],
      user: current_user,  # Explicitly set to current_user, ignoring any user_id in params
      source_code: submission_params_hash[:source_code],
      status: "queued"
    )

    SubmissionJob.perform_async(submission.id)

    submission
  rescue StandardError => e
    Rails.logger.error("Submission failed: #{e.message}")
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
    uuid = SecureRandom.uuid
    source_code_file = "/tmp/#{uuid}.#{language.extension}"
    File.write(source_code_file, source_code)
    
    start_time = Time.now
    
    begin
      # Compile if needed (compilation happens outside nsjail for now)
      if language.compiler_binary.present?
        compiled_file = "/tmp/#{uuid}"
        
        # Replace placeholders in compiler flags
        flags_with_paths = language.compiler_flags.gsub("{compiled_file}", compiled_file)
                                           .gsub("{source_file}", source_code_file)
        
        # Split flags into array (handles spaces, but not quoted args - acceptable for our use case)
        # This prevents command injection by passing arguments as separate array elements
        compiler_args = flags_with_paths.split(/\s+/).reject(&:empty?)
        
        Rails.logger.info "Compiling with: #{language.compiler_binary} #{compiler_args.join(' ')}"
        
        # Use Open3.capture3 with array arguments to prevent command injection
        stdout, stderr, status = Open3.capture3(language.compiler_binary, *compiler_args)
        
        if !status.success?
          compiler_errors = stderr.present? ? stderr : "Compilation failed (no error details)"
          Rails.logger.error "Compilation failed: #{compiler_errors}"
          
          File.delete(source_code_file) rescue nil
          
          return {
            status: "compilation_error",
            output: "",
            runtime: 0,
            error_message: "Compilation failed:\n#{compiler_errors}"
          }
        end
      end
      
      # Prepare test case
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)
      
      output_file = "/tmp/#{uuid}_program.out"
      File.write(output_file, "")  # Create empty output file
      
      # Calculate resource limits
      time_limit = [language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_mb = [language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max / 1024
      
      Rails.logger.info "Executing with nsjail: timeout=#{time_limit}s, memory=#{memory_limit_mb}MB"
      
      # Execute using nsjail
      if language.compiler_binary.present?
        # Execute compiled binary
        result = NsjailExecutionService.execute_compiled(
          timeout_sec: time_limit,
          memory_limit_mb: memory_limit_mb,
          compiled_file: compiled_file,
          input_file: input_file,
          output_file: output_file
        )
      else
        # Execute interpreted code
        result = NsjailExecutionService.new(
          language_name: language.name,
          timeout_sec: time_limit,
          memory_limit_mb: memory_limit_mb,
          source_file: source_code_file,
          input_file: input_file,
          output_file: output_file
        ).execute
      end
      
      runtime = Time.now - start_time
      
      Rails.logger.info "Execution result: exit_code=#{result.exit_code}, timed_out=#{result.timed_out}, oom_killed=#{result.oom_killed}"
      
      # Map nsjail results to test status
      if result.timed_out
        status = "time_limit_exceeded"
        output = ""
        error_message = "Time limit exceeded (> #{time_limit}s)"
      elsif result.oom_killed
        status = "memory_limit_exceeded"
        output = ""
        error_message = "Memory limit exceeded"
      elsif !result.success?
        status = "runtime_error"
        output = result.stdout
        error_message = "Runtime error (exit code #{result.exit_code})"
        error_message += "\n#{result.stderr}" if result.stderr.present?
      else
        # Read output and compare
        actual_output = result.stdout
        expected_output = example.output
        
        if actual_output == expected_output
          status = "passed"
          output = actual_output
          error_message = nil
        else
          # Try whitespace-insensitive comparison
          if actual_output.gsub(/\s+/, "") == expected_output.gsub(/\s+/, "")
            status = "presentation_error"
            output = actual_output
            error_message = "Output is correct but formatting differs"
          else
            status = "wrong_answer"
            output = actual_output
            error_message = "Output does not match expected"
          end
        end
      end
      
      # Cleanup
      File.delete(source_code_file) rescue nil
      File.delete(input_file) rescue nil
      File.delete(output_file) rescue nil
      File.delete(compiled_file) rescue nil if language.compiler_binary.present?
      
      {
        status: status,
        output: output,
        runtime: (runtime * 1000).round, # Convert to ms
        error_message: error_message
      }
    rescue StandardError => e
      Rails.logger.error "Error in run_single_test: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Cleanup on error
      File.delete(source_code_file) rescue nil
      File.delete(input_file) rescue nil
      File.delete(output_file) rescue nil
      File.delete(compiled_file) rescue nil if defined?(compiled_file) && language.compiler_binary.present?
      
      {
        status: "error",
        output: "",
        runtime: 0,
        error_message: "System error: #{e.message}"
      }
    end
  end
end
