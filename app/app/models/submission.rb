# frozen_string_literal: true

class Submission < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language
  belongs_to :user

  validates :source_code, presence: true
  validates :status, presence: true

  DEBUG = true
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

      expected_output_file = "/tmp/#{uuid}.out"
      File.write(expected_output_file, example.output)

      output_file = "/tmp/#{uuid}_program.out"

      interpreter_binary = self.programming_language.interpreter_binary
      interpreter_flags = self.programming_language.interpreter_flags

      time_limit = [self.programming_language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_kb = [self.programming_language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max
      memory_limit_kb = 1024 * memory_limit_kb

      debug!("#{__LINE__} memory_limit_kb = #{memory_limit_kb}")

      command = "ulimit -m #{memory_limit_kb}; ulimit -v #{memory_limit_kb}; timeout #{time_limit}s #{interpreter_binary} #{interpreter_flags} #{source_code_file} < #{input_file} > #{output_file}; echo $?"

      debug!("#{__LINE__}: running #{command}")
      result = `#{command}`
      debug!("#{__LINE__}: result = #{result}")

      final_status = TIME_LIMIT_EXCEEDED if result == "124\n"
      final_status = MEMORY_LIMIT_EXCEEDED if result == "133\n"

      output = File.read(output_file)
      expected_output = File.read(expected_output_file)

      begin
        unless DEBUG
          File.delete(input_file)
          File.delete(expected_output_file)
          File.delete(output_file)
        end
      rescue StandardError => e
        debug!("#{__LINE__} error: #{e.message}")
      end

      break if final_status != ACCEPTED

      if output == expected_output
        next
      else
        output.gsub!(/\s+/, "")
        expected_output.gsub!(/\s+/, "")
        if output == expected_output
          final_status = PRESENTATION_ERROR
        else
          final_status = WRONG_ANSWER + " (example #{index + 1})"
        end
        break
      end
    end

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
    compiler_command = "#{compiler_binary} #{compiler_flags}; echo $?"

    debug!("#{__LINE__}: running #{compiler_command}")

    compiler_command.gsub!("{compiled_file}", "/tmp/#{uuid}")
    compiler_command.gsub!("{source_file}", source_code_file)

    self.update!(status: COMPILING)
    result = `#{compiler_command}`

    if result != "0\n"
      self.update!(status: COMPILATION_ERROR)

      return
    end

    final_status = ACCEPTED

    self.update!(status: RUNNING)
    problem.examples.order(:id).each_with_index do |example, index|
      input_file = "/tmp/#{uuid}.in"
      File.write(input_file, example.input)

      expected_output_file = "/tmp/#{uuid}.out"
      File.write(expected_output_file, example.output)

      output_file = "/tmp/#{uuid}_program.out"

      time_limit = [self.programming_language.time_limit_sec, problem.time_limit_sec].max
      memory_limit_kb = [self.programming_language.memory_limit_kb.to_i, problem.memory_limit_kb.to_i].max
      memory_limit_kb = 1024 * memory_limit_kb

      debug!("#{__LINE__} memory_limit_kb = #{memory_limit_kb}")

      command = "ulimit -m #{memory_limit_kb}; ulimit -v #{memory_limit_kb}; timeout #{time_limit}s /tmp/#{uuid} < #{input_file} > #{output_file}; echo $?"
      debug!("#{__LINE__}: running #{command}")

      result = `#{command}`
      debug!("#{__LINE__}: result = #{result}")

      final_status = TIME_LIMIT_EXCEEDED if result == "124\n"
      final_status = MEMORY_LIMIT_EXCEEDED if result == "133\n"

      output = File.read(output_file)
      expected_output = File.read(expected_output_file)

      begin
        unless DEBUG
          File.delete(input_file)
          File.delete(expected_output_file)
          File.delete(output_file)
        end
      rescue StandardError => e
        debug!("#{__LINE__} error: #{e.message}")
      end

      break if final_status != ACCEPTED

      if output == expected_output
        next
      else
        output.gsub!(/\s+/, "")
        expected_output.gsub!(/\s+/, "")
        if output == expected_output
          final_status = PRESENTATION_ERROR
        else
          final_status = WRONG_ANSWER + " (example #{index + 1})"
        end
        break
      end
    end

    File.delete(source_code_file) unless DEBUG

    time_used = Time.now - start_time
    self.update!(time_used: time_used)
    self.update!(status: final_status)
  end

  private

  def debug!(message)
    File.write("/tmp/debug", "#{message}\n", mode: 'a') if DEBUG
  end
end
