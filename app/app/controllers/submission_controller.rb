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
  
  def test_code
    begin
      Rails.logger.info "=== TEST_CODE METHOD CALLED ==="
      
      problem = Problem.find(params[:problem_id])
      Rails.logger.info "Problem found: #{problem.title}"
      
      language = ProgrammingLanguage.find(params[:programming_language_id])
      Rails.logger.info "Language found: #{language.name}"
      
      source_code = params[:source_code].read
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
      # Compile if needed
      if language.compiler_binary.present?
        compiler_output_file = "/tmp/#{uuid}_compile.out"
        compiler_command = "#{language.compiler_binary} #{language.compiler_flags} 2> #{compiler_output_file}; echo $?"
        compiler_command.gsub!("{compiled_file}", "/tmp/#{uuid}")
        compiler_command.gsub!("{source_file}", source_code_file)
        
        Rails.logger.info "Compiling with: #{compiler_command}"
        compile_result = `#{compiler_command}`.strip
        
        if compile_result != "0"
          # Read compiler error output
          compiler_errors = File.read(compiler_output_file) rescue "Compilation failed (no error details)"
          Rails.logger.error "Compilation failed: #{compiler_errors}"
          
          File.delete(source_code_file) rescue nil
          File.delete(compiler_output_file) rescue nil
          
          return {
            status: "compilation_error",
            output: "",
            runtime: 0,
            error_message: "Compilation failed:\n#{compiler_errors}"
          }
        end
        
        # Cleanup compiler output file
        File.delete(compiler_output_file) rescue nil
        
        executable = "/tmp/#{uuid}"
      else
        executable = "#{language.interpreter_binary} #{language.interpreter_flags} #{source_code_file}"
      end
      
      # Prepare test case
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)
      
      output_file = "/tmp/#{uuid}_program.out"
      error_file = "/tmp/#{uuid}_program.err"
      
      time_limit = [language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_kb = [language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max * 1024
      
      # Run the code (capture both stdout and stderr)
      command = "ulimit -m #{memory_limit_kb}; ulimit -v #{memory_limit_kb}; timeout #{time_limit}s #{executable} < #{input_file} > #{output_file} 2> #{error_file}; echo $?"
      
      exit_code_output = `#{command}`.strip
      runtime = Time.now - start_time
      
      Rails.logger.info "Exit code: #{exit_code_output}"
      
      # Check exit code
      if exit_code_output == "124"
        status = "time_limit_exceeded"
        output = ""
        error_message = "Time limit exceeded (> #{time_limit}s)"
      elsif exit_code_output == "133"
        status = "memory_limit_exceeded"
        output = ""
        error_message = "Memory limit exceeded"
      elsif exit_code_output != "0"
        status = "runtime_error"
        output = File.read(output_file) rescue ""
        error_output = File.read(error_file) rescue ""
        error_message = "Runtime error (exit code #{exit_code_output})"
        error_message += "\n#{error_output}" if error_output.present?
      else
        # Read output and compare
        actual_output = File.read(output_file) rescue ""
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
      File.delete(error_file) rescue nil
      File.delete("/tmp/#{uuid}") rescue nil if language.compiler_binary.present?
      
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
      File.delete(error_file) rescue nil
      File.delete("/tmp/#{uuid}") rescue nil
      
      {
        status: "error",
        output: "",
        runtime: 0,
        error_message: "System error: #{e.message}"
      }
    end
  end
end
