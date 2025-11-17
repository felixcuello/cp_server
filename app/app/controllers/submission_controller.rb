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
    result = test_code
    
    respond_to do |format|
      format.json { render json: result }
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
      problem = Problem.find(params[:problem_id])
      language = ProgrammingLanguage.find(params[:programming_language_id])
      source_code = params[:source_code].read
      
      # Get visible examples only
      examples = problem.examples.where(is_hidden: false).order(:id)
      
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
        result = run_single_test(source_code, language, example, problem)
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
      
      {
        success: true,
        overall_status: overall_status,
        test_results: results
      }
    rescue StandardError => e
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
        compiler_command = "#{language.compiler_binary} #{language.compiler_flags}; echo $?"
        compiler_command.gsub!("{compiled_file}", "/tmp/#{uuid}")
        compiler_command.gsub!("{source_file}", source_code_file)
        
        compile_result = `#{compiler_command}`
        
        if compile_result != "0\n"
          File.delete(source_code_file) rescue nil
          return {
            status: "compilation_error",
            output: "",
            runtime: 0,
            error_message: "Compilation failed"
          }
        end
        
        executable = "/tmp/#{uuid}"
      else
        executable = "#{language.interpreter_binary} #{language.interpreter_flags} #{source_code_file}"
      end
      
      # Prepare test case
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)
      
      output_file = "/tmp/#{uuid}_program.out"
      
      time_limit = [language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_kb = [language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max * 1024
      
      # Run the code
      command = "ulimit -m #{memory_limit_kb}; ulimit -v #{memory_limit_kb}; timeout #{time_limit}s #{executable} < #{input_file} > #{output_file} 2>&1; echo $?"
      
      exit_code_output = `#{command}`
      runtime = Time.now - start_time
      
      # Check exit code
      if exit_code_output.strip == "124"
        status = "time_limit_exceeded"
        output = ""
        error_message = "Time limit exceeded"
      elsif exit_code_output.strip == "133"
        status = "memory_limit_exceeded"
        output = ""
        error_message = "Memory limit exceeded"
      elsif exit_code_output.strip != "0"
        status = "runtime_error"
        output = File.read(output_file) rescue ""
        error_message = "Runtime error"
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
      File.delete("/tmp/#{uuid}") rescue nil if language.compiler_binary.present?
      
      {
        status: status,
        output: output,
        runtime: (runtime * 1000).round, # Convert to ms
        error_message: error_message
      }
    rescue StandardError => e
      # Cleanup on error
      File.delete(source_code_file) rescue nil
      File.delete(input_file) rescue nil
      File.delete(output_file) rescue nil
      File.delete("/tmp/#{uuid}") rescue nil
      
      {
        status: "error",
        output: "",
        runtime: 0,
        error_message: e.message
      }
    end
  end
end
