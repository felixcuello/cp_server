# frozen_string_literal: true

require 'open3'

# Service for executing code against a single test case/example
# Used by both Submission model and SubmissionController to avoid code duplication
class SubmissionService
  def initialize(source_code:, language:, example:, problem:, compiled_binary_path: nil)
    @source_code = source_code
    @language = language
    @example = example
    @problem = problem
    @uuid = SecureRandom.uuid
    @precompiled_binary = compiled_binary_path  # If provided, skip compilation
  end

  # Execute the test and return a result hash
  def execute
    if problem.function_based?
      execute_function_based
    else
      execute_stdin_stdout
    end
  end

  private

  def execute_function_based
    # Use FunctionBasedTestingService for function-based problems
    service = FunctionBasedTestingService.new(
      problem: problem,
      language: language,
      user_code: source_code,
      example: example
    )

    begin
      service.execute
    rescue FunctionBasedTestingService::CompilationError => e
      {
        status: "compilation_error",
        output: "",
        runtime: 0,
        error_message: "Compilation failed:\n#{e.message}"
      }
    end
  end

  def execute_stdin_stdout
    prepare_files
    compile_if_needed unless @precompiled_binary
    execute_code
    compare_outputs
  ensure
    cleanup_files
  end

  attr_reader :source_code, :language, :example, :problem, :uuid

  def prepare_files
    @source_code_file = "/tmp/#{uuid}.#{language.extension}"
    File.write(@source_code_file, source_code)

    @input_file = "/tmp/#{uuid}.in"
    File.write(@input_file, example.input)

    @output_file = "/tmp/#{uuid}_program.out"
    File.write(@output_file, "")
  end

  def compile_if_needed
    return unless language.compiler_binary.present?

    @compiled_file = "/tmp/#{uuid}"

    # Replace placeholders in compiler flags
    flags_with_paths = language.compiler_flags.gsub("{compiled_file}", @compiled_file)
                                   .gsub("{source_file}", @source_code_file)

    # Split flags into array (handles spaces, but not quoted args - acceptable for our use case)
    # This prevents command injection by passing arguments as separate array elements
    compiler_args = flags_with_paths.split(/\s+/).reject(&:empty?)

    Rails.logger.info "Compiling with: #{language.compiler_binary} #{compiler_args.join(' ')}"

    # Use Open3.capture3 with array arguments to prevent command injection
    stdout, stderr, status = Open3.capture3(language.compiler_binary, *compiler_args)

    unless status.success?
      compiler_errors = stderr.present? ? stderr : "Compilation failed (no error details)"
      Rails.logger.error "Compilation failed: #{compiler_errors}"
      raise CompilationError, compiler_errors
    end
  end

  # Class method to compile code once and return the binary path
  # Used for optimization when running multiple test cases
  def self.compile_once(source_code:, language:)
    uuid = SecureRandom.uuid
    source_file = "/tmp/#{uuid}.#{language.extension}"
    compiled_file = "/tmp/#{uuid}"

    File.write(source_file, source_code)

    flags_with_paths = language.compiler_flags.gsub("{compiled_file}", compiled_file)
                                   .gsub("{source_file}", source_file)
    compiler_args = flags_with_paths.split(/\s+/).reject(&:empty?)

    Rails.logger.info "Compiling once with: #{language.compiler_binary} #{compiler_args.join(' ')}"

    stdout, stderr, status = Open3.capture3(language.compiler_binary, *compiler_args)

    # Clean up source file immediately (we only need the binary)
    File.delete(source_file) rescue nil

    unless status.success?
      # Clean up binary if compilation failed
      File.delete(compiled_file) rescue nil
      compiler_errors = stderr.present? ? stderr : "Compilation failed (no error details)"
      raise CompilationError, compiler_errors
    end

    compiled_file
  end

  def execute_code
    # Calculate resource limits
    time_limit = [language.time_limit_sec, problem.time_limit_sec].max
    memory_limit_mb = [language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max / 1024

    Rails.logger.info "Executing with nsjail: timeout=#{time_limit}s, memory=#{memory_limit_mb}MB"

    if language.compiler_binary.present?
      # Use precompiled binary if provided, otherwise use the one we just compiled
      binary_to_execute = @precompiled_binary || @compiled_file

      # Execute compiled binary
      @execution_result = NsjailExecutionService.execute_compiled(
        timeout_sec: time_limit,
        memory_limit_mb: memory_limit_mb,
        compiled_file: binary_to_execute,
        input_file: @input_file,
        output_file: @output_file
      )
    else
      # Execute interpreted code
      @execution_result = NsjailExecutionService.new(
        language_name: language.name,
        timeout_sec: time_limit,
        memory_limit_mb: memory_limit_mb,
        source_file: @source_code_file,
        input_file: @input_file,
        output_file: @output_file
      ).execute
    end

    # Use execution time from nsjail result (in milliseconds), convert to seconds
    # This is more accurate as it measures the actual execution time
    @runtime = @execution_result.execution_time_ms / 1000.0
    Rails.logger.info "Execution result: exit_code=#{@execution_result.exit_code}, timed_out=#{@execution_result.timed_out}, oom_killed=#{@execution_result.oom_killed}, execution_time_ms=#{@execution_result.execution_time_ms}"
  end

  def compare_outputs
    # Map nsjail results to test status
    if @execution_result.timed_out
      {
        status: "time_limit_exceeded",
        output: "",
        runtime: (@runtime * 1000).round,
        error_message: "Time limit exceeded (> #{[language.time_limit_sec, problem.time_limit_sec].max}s)"
      }
    elsif @execution_result.oom_killed
      {
        status: "memory_limit_exceeded",
        output: "",
        runtime: (@runtime * 1000).round,
        error_message: "Memory limit exceeded"
      }
    elsif !@execution_result.success?
      {
        status: "runtime_error",
        output: @execution_result.stdout,
        runtime: (@runtime * 1000).round,
        error_message: "Runtime error (exit code #{@execution_result.exit_code})" +
                       (@execution_result.stderr.present? ? "\n#{@execution_result.stderr}" : "")
      }
    else
      # Read output and compare
      actual_output = @execution_result.stdout
      expected_output = example.output

      # Check if outputs match based on problem's ignore_output_line_order flag
      outputs_match = if problem.ignore_output_line_order
        # Sort lines before comparison for problems where line order doesn't matter
        actual_lines = actual_output.strip.split("\n").sort
        expected_lines = expected_output.strip.split("\n").sort
        actual_lines == expected_lines
      else
        # Exact match for regular problems
        actual_output == expected_output
      end

      if outputs_match
        {
          status: "passed",
          output: actual_output,
          runtime: (@runtime * 1000).round,
          error_message: nil
        }
      else
        # Try whitespace-insensitive comparison
        if actual_output.gsub(/\s+/, "") == expected_output.gsub(/\s+/, "")
          {
            status: "presentation_error",
            output: actual_output,
            runtime: (@runtime * 1000).round,
            error_message: "Output is correct but formatting differs"
          }
        else
          {
            status: "wrong_answer",
            output: actual_output,
            runtime: (@runtime * 1000).round,
            error_message: "Output does not match expected"
          }
        end
      end
    end
  end

  def cleanup_files
    File.delete(@source_code_file) rescue nil if @source_code_file
    File.delete(@input_file) rescue nil if @input_file
    File.delete(@output_file) rescue nil if @output_file
    # Only delete compiled file if we compiled it ourselves (not precompiled)
    File.delete(@compiled_file) rescue nil if @compiled_file && !@precompiled_binary && language.compiler_binary.present?
  end

  # Custom exception for compilation errors
  class CompilationError < StandardError; end
end
