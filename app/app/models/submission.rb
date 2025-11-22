# frozen_string_literal: true

require 'open3'

class Submission < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language
  belongs_to :user

  validates :source_code, presence: true
  validates :status, presence: true

  # Security: Ensure user_id cannot be set to a different user than the user association
  # This prevents mass assignment attacks where someone tries to submit as another user
  before_validation :ensure_user_id_matches_user_association, on: :create
  before_save :prevent_user_id_change, if: :persisted?

  # Update problem statistics after submission status changes
  after_save :update_problem_statistics, if: :saved_change_to_status?
  after_save :update_user_problem_status, if: :saved_change_to_status?

  DEBUG = false
  ACCEPTED = "accepted"
  COMPILATION_ERROR = "compilation error"
  COMPILING = "compiling"
  MEMORY_LIMIT_EXCEEDED = "memory limit exceeded"
  PRESENTATION_ERROR = "presentation error"
  RUNNING = "running"
  RUNTIME_ERROR = "runtime error"
  TIME_LIMIT_EXCEEDED = "time limit exceeded"
  WRONG_ANSWER = "wrong answer"
  ENQUEUED = "enqueued"

  def run!
    self.update!(status: ENQUEUED)

    if self.programming_language.compiler_binary != ""
      run_with_compiler!
    else
      run_with_interpreter!
    end
  end

  def run_with_interpreter!
    uuid = SecureRandom.uuid
    source_code_file = "/tmp/#{uuid}.#{self.programming_language.extension}"
    File.write(source_code_file, self.source_code)

    problem = Problem.find self.problem_id
    start_time = Time.now

    final_status = ACCEPTED

    self.update!(status: RUNNING)
    problem.examples.order(:id).each_with_index do |example, index|
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)

      output_file = "/tmp/#{uuid}_program.out"
      File.write(output_file, "")  # Create empty output file

      # Calculate resource limits (use max of language and problem limits)
      time_limit = [self.programming_language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_mb = [self.programming_language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max / 1024

      debug!("#{__LINE__} Executing with nsjail: timeout=#{time_limit}s, memory=#{memory_limit_mb}MB")

      # Execute using nsjail
      result = NsjailExecutionService.new(
        language_name: self.programming_language.name,
        timeout_sec: time_limit,
        memory_limit_mb: memory_limit_mb,
        source_file: source_code_file,
        input_file: input_file,
        output_file: output_file
      ).execute

      debug!("#{__LINE__} Execution result: exit_code=#{result.exit_code}, timed_out=#{result.timed_out}")

      # Check for time limit exceeded
      if result.timed_out
        final_status = TIME_LIMIT_EXCEEDED
      elsif result.oom_killed
        final_status = MEMORY_LIMIT_EXCEEDED
      elsif !result.success?
        final_status = RUNTIME_ERROR
      end

      # Read and compare output
      output = result.stdout
      expected_output = example.output

      # Clean up temp files
      begin
        unless DEBUG
          File.delete(input_file)
          File.delete(output_file)
        end
      rescue StandardError => e
        debug!("#{__LINE__} error deleting files: #{e.message}")
      end

      # Break if we already have a non-accepted status
      break if final_status != ACCEPTED

      # Compare outputs
      if output == expected_output
        next
      else
        # Try with normalized whitespace
        output_normalized = output.gsub(/\s+/, "")
        expected_normalized = expected_output.gsub(/\s+/, "")

        if output_normalized == expected_normalized
          final_status = PRESENTATION_ERROR
        else
          final_status = WRONG_ANSWER + " (example #{index + 1})"
        end
        break
      end
    end

    # Clean up source file
    File.delete(source_code_file) unless DEBUG

    time_used = Time.now - start_time
    self.update!(time_used: time_used)
    self.update!(status: final_status)
  end

  def run_with_compiler!
    uuid = SecureRandom.uuid
    source_code_file = "/tmp/#{uuid}.#{self.programming_language.extension}"
    File.write(source_code_file, self.source_code)

    problem = Problem.find self.problem_id
    start_time = Time.now

    compiler_binary = self.programming_language.compiler_binary
    compiler_flags = self.programming_language.compiler_flags
    compiled_file = "/tmp/#{uuid}"

    # Replace placeholders in compiler flags
    flags_with_paths = compiler_flags.gsub("{compiled_file}", compiled_file)
                                     .gsub("{source_file}", source_code_file)

    # Split flags into array (handles spaces, but not quoted args - acceptable for our use case)
    # This prevents command injection by passing arguments as separate array elements
    compiler_args = flags_with_paths.split(/\s+/).reject(&:empty?)

    debug!("#{__LINE__}: running #{compiler_binary} #{compiler_args.join(' ')}")

    self.update!(status: COMPILING)

    # Compilation happens outside nsjail for now
    # TODO: Move compilation inside nsjail in future iteration
    # Use Open3.capture3 with array arguments to prevent command injection
    stdout, stderr, status = Open3.capture3(compiler_binary, *compiler_args)

    if !status.success?
      self.update!(status: COMPILATION_ERROR)
      File.delete(source_code_file) unless DEBUG
      return
    end

    final_status = ACCEPTED

    self.update!(status: RUNNING)

    problem.examples.order(:id).each_with_index do |example, index|
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)

      output_file = "/tmp/#{uuid}_program.out"
      File.write(output_file, "")

      # Calculate resource limits
      time_limit = [self.programming_language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_mb = [self.programming_language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max / 1024

      debug!("#{__LINE__} Executing compiled binary with nsjail: timeout=#{time_limit}s, memory=#{memory_limit_mb}MB")

      # Execute compiled binary using nsjail
      result = NsjailExecutionService.execute_compiled(
        timeout_sec: time_limit,
        memory_limit_mb: memory_limit_mb,
        compiled_file: compiled_file,
        input_file: input_file,
        output_file: output_file
      )

      debug!("#{__LINE__} Execution result: exit_code=#{result.exit_code}, timed_out=#{result.timed_out}")

      # Check for errors
      if result.timed_out
        final_status = TIME_LIMIT_EXCEEDED
      elsif result.oom_killed
        final_status = MEMORY_LIMIT_EXCEEDED
      elsif !result.success?
        final_status = RUNTIME_ERROR
      end

      # Read and compare output
      output = result.stdout
      expected_output = example.output

      # Clean up temp files
      begin
        unless DEBUG
          File.delete(input_file)
          File.delete(output_file)
        end
      rescue StandardError => e
        debug!("#{__LINE__} error deleting files: #{e.message}")
      end

      break if final_status != ACCEPTED

      # Compare outputs
      if output == expected_output
        next
      else
        output_normalized = output.gsub(/\s+/, "")
        expected_normalized = expected_output.gsub(/\s+/, "")

        if output_normalized == expected_normalized
          final_status = PRESENTATION_ERROR
        else
          final_status = WRONG_ANSWER + " (example #{index + 1})"
        end
        break
      end
    end

    # Clean up
    File.delete(source_code_file) unless DEBUG
    File.delete(compiled_file) unless DEBUG

    time_used = Time.now - start_time
    self.update!(time_used: time_used)
    self.update!(status: final_status)
  end

  private

  # Security: Ensure that if user_id is set directly, it matches the user association
  # This prevents users from submitting as other users
  def ensure_user_id_matches_user_association
    if user.present?
      # Always use the user association to set user_id - ignore any user_id that was set directly
      self.user_id = user.id
    end
  end

  # Security: Prevent changing user_id after submission is created
  # This ensures a submission always belongs to the user who created it
  def prevent_user_id_change
    if user_id_changed? && persisted?
      self.user_id = user_id_was
      Rails.logger.warn("Attempted to change user_id on submission #{id} from #{user_id_was} to #{user_id}. Blocked.")
      errors.add(:user_id, "cannot be changed after submission is created")
    end
  end

  def debug!(message)
    File.write("/tmp/debug", "#{message}\n", mode: 'a') if DEBUG
  end

  def update_problem_statistics
    problem.update_statistics!
  end

  def update_user_problem_status
    user_status = UserProblemStatus.find_or_initialize_by(user: user, problem: problem)

    # If this submission is accepted, mark as solved
    if status == ACCEPTED
      user_status.status = 'solved'
      user_status.save!
    # Otherwise, if not already solved, mark as attempted
    elsif user_status.status != 'solved'
      user_status.status = 'attempted'
      user_status.save!
    end
  end
end
