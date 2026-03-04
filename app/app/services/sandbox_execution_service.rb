# frozen_string_literal: true

require 'open3'

class SandboxExecutionService
  class CompilationError < StandardError; end

  MAX_SOURCE_SIZE = 100 * 1024  # 100 KB
  MAX_INPUT_SIZE = 1 * 1024 * 1024  # 1 MB
  TIMEOUT_SEC = 5
  MEMORY_LIMIT_MB = 256

  def initialize(source_code:, language:, input:)
    @source_code = source_code
    @language = language
    @input = input || ""
    @uuid = SecureRandom.uuid
  end

  def execute
    validate!
    prepare_files
    compile_if_needed
    run_code
    build_result
  rescue CompilationError => e
    { status: "compilation_error", output: "", error: e.message, runtime_ms: 0 }
  rescue => e
    Rails.logger.error "SandboxExecutionService error: #{e.message}"
    { status: "error", output: "", error: e.message, runtime_ms: 0 }
  ensure
    cleanup_files
  end

  private

  def validate!
    if @source_code.bytesize > MAX_SOURCE_SIZE
      raise "Source code too large (max #{MAX_SOURCE_SIZE / 1024}KB)"
    end

    if @input.bytesize > MAX_INPUT_SIZE
      raise "Input too large (max #{MAX_INPUT_SIZE / 1024}KB)"
    end
  end

  def prepare_files
    @source_file = "/tmp/#{@uuid}.#{@language.extension}"
    File.write(@source_file, @source_code)

    @input_file = "/tmp/#{@uuid}.in"
    File.write(@input_file, @input)

    @output_file = "/tmp/#{@uuid}_sandbox.out"
    File.write(@output_file, "")
  end

  def compile_if_needed
    return unless @language.compiler_binary.present?

    @compiled_file = "/tmp/#{@uuid}"

    flags_with_paths = @language.compiler_flags
                                .gsub("{compiled_file}", @compiled_file)
                                .gsub("{source_file}", @source_file)

    compiler_args = flags_with_paths.split(/\s+/).reject(&:empty?)

    _stdout, stderr, status = Open3.capture3(@language.compiler_binary, *compiler_args)

    unless status.success?
      raise CompilationError, stderr.present? ? stderr : "Compilation failed (no error details)"
    end
  end

  def run_code
    if @language.compiler_binary.present?
      @execution_result = NsjailExecutionService.execute_compiled(
        timeout_sec: TIMEOUT_SEC,
        memory_limit_mb: MEMORY_LIMIT_MB,
        compiled_file: @compiled_file,
        input_file: @input_file,
        output_file: @output_file
      )
    else
      @execution_result = NsjailExecutionService.new(
        language_name: @language.name,
        timeout_sec: TIMEOUT_SEC,
        memory_limit_mb: MEMORY_LIMIT_MB,
        source_file: @source_file,
        input_file: @input_file,
        output_file: @output_file
      ).execute
    end
  end

  def build_result
    if @execution_result.timed_out
      {
        status: "time_limit_exceeded",
        output: @execution_result.stdout,
        error: "Time limit exceeded (> #{TIMEOUT_SEC}s)",
        runtime_ms: @execution_result.execution_time_ms
      }
    elsif @execution_result.oom_killed
      {
        status: "memory_limit_exceeded",
        output: @execution_result.stdout,
        error: "Memory limit exceeded (> #{MEMORY_LIMIT_MB}MB)",
        runtime_ms: @execution_result.execution_time_ms
      }
    elsif !@execution_result.success?
      {
        status: "runtime_error",
        output: @execution_result.stdout,
        error: "Runtime error (exit code #{@execution_result.exit_code})" +
               (@execution_result.stderr.present? ? "\n#{@execution_result.stderr}" : ""),
        runtime_ms: @execution_result.execution_time_ms
      }
    else
      {
        status: "success",
        output: @execution_result.stdout,
        error: nil,
        runtime_ms: @execution_result.execution_time_ms
      }
    end
  end

  def cleanup_files
    File.delete(@source_file) rescue nil if @source_file
    File.delete(@input_file) rescue nil if @input_file
    File.delete(@output_file) rescue nil if @output_file
    File.delete(@compiled_file) rescue nil if @compiled_file && @language&.compiler_binary.present?
  end
end
