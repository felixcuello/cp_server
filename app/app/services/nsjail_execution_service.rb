# frozen_string_literal: true

require 'securerandom'
require 'open3'

# Service for executing user code in an isolated nsjail sandbox
# This provides security through Linux namespaces, cgroups, and seccomp
class NsjailExecutionService
  class ExecutionResult
    attr_accessor :exit_code, :stdout, :stderr, :timed_out, :oom_killed, :execution_time_ms

    def initialize
      @exit_code = nil
      @stdout = ""
      @stderr = ""
      @timed_out = false
      @oom_killed = false
      @execution_time_ms = 0
    end

    def success?
      exit_code == 0
    end
  end

  # Configuration constants
  CHROOT_PATH = "/chroot"
  WORKSPACE_PATH = "/workspace"
  NSJAIL_BINARY = "/usr/local/bin/nsjail"

  # Security limits
  MAX_FILE_SIZE_MB = 10
  MAX_PROCESSES = 50
  MAX_FILE_DESCRIPTORS = 100

  def initialize(
    language_name:,
    timeout_sec:,
    memory_limit_mb:,
    source_file:,
    input_file:,
    output_file:
  )
    @language_name = language_name
    @timeout_sec = timeout_sec
    @memory_limit_mb = memory_limit_mb
    @source_file = source_file
    @input_file = input_file
    @output_file = output_file
  end

  # Execute the code in isolated environment
  def execute
    result = ExecutionResult.new
    start_time = Time.now

    # Debug: Check if chroot exists and what's in it
    if Dir.exist?(CHROOT_PATH)
      interpreter = get_interpreter_for_language
      interpreter_path_in_chroot = interpreter
      full_path = File.join(CHROOT_PATH, interpreter_path_in_chroot[1..-1]) # Remove leading /

      unless File.exist?(full_path)
        result.stderr = "ERROR: Interpreter not found in chroot. Expected: #{full_path}\n"
        result.stderr += "Chroot contents of /usr/bin: #{Dir.glob(File.join(CHROOT_PATH, 'usr/bin/*')).join(', ')}\n" if Dir.exist?(File.join(CHROOT_PATH, 'usr/bin'))
        result.stderr += "Chroot exists: #{Dir.exist?(CHROOT_PATH)}\n"
        result.exit_code = 127
        return result
      end
    else
      result.stderr = "ERROR: Chroot directory #{CHROOT_PATH} does not exist!"
      result.exit_code = 127
      return result
    end

    # Build the nsjail command
    command = build_nsjail_command

    # Execute with timeout and measure CPU time
    begin
      # Check if /usr/bin/time is available, otherwise fall back to wall-clock time
      time_binary = "/usr/bin/time"
      use_cpu_time = File.exist?(time_binary)

      if use_cpu_time
        # Use /usr/bin/time to measure CPU time and execute in one go
        # Format: %U = user CPU time, %S = system CPU time, %e = elapsed time, %x = exit status
        # /usr/bin/time writes to stderr, so we capture stderr separately
        # Use Open3 to properly handle stdout/stderr streams
        time_command = "#{time_binary} -f 'TIME_STATS:%U %S %e %x' #{command}"
        stdout_str, stderr_str, status = Open3.capture3(time_command)

        exit_code = status.exitstatus

        # Parse timing stats from stderr
        timing_stats = nil
        if stderr_str =~ /TIME_STATS:(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)/
          user_time = $1.to_f
          system_time = $2.to_f
          elapsed_time = $3.to_f
          exit_code_from_time = $4.to_i

          # Use exit code from /usr/bin/time if available (more reliable)
          exit_code = exit_code_from_time if exit_code_from_time != 0 || exit_code == 0

          # Use CPU time (user + system) in milliseconds - this is more accurate
          # as it measures actual CPU time used, not wall-clock time
          timing_stats = ((user_time + system_time) * 1000).to_i
        end

        # Store any stderr output (excluding timing info)
        if stderr_str.present? && !stderr_str.match(/TIME_STATS:/)
          result.stderr = stderr_str
        end
      else
        # Fallback: execute command normally and use wall-clock time
        stdout_str, stderr_str, status = Open3.capture3(command)
        exit_code = status.exitstatus

        if stderr_str.present?
          result.stderr = stderr_str
        end
      end

      result.exit_code = exit_code

      if use_cpu_time && timing_stats
        result.execution_time_ms = timing_stats
      else
        # Fallback: use wall-clock time (includes nsjail overhead)
        result.execution_time_ms = ((Time.now - start_time) * 1000).to_i
      end

      # Check for specific error conditions
      result.timed_out = (result.exit_code == 137 || result.exit_code == 124) # SIGKILL or timeout
      result.oom_killed = (result.exit_code == 137) # Could also be OOM

      # Read output from file (the program's stdout is redirected to the output file inside nsjail)
      if File.exist?(@output_file)
        result.stdout = File.read(@output_file)
      end

    rescue => e
      result.stderr = "Execution error: #{e.message}"
      result.exit_code = 1
      # Use wall-clock time as fallback
      result.execution_time_ms = ((Time.now - start_time) * 1000).to_i
    ensure
      # Clean up time stats file if it still exists
      File.delete(@time_stats_file) rescue nil
    end

    result
  end

  # Execute compiled binary
  def self.execute_compiled(
    timeout_sec:,
    memory_limit_mb:,
    compiled_file:,
    input_file:,
    output_file:
  )
    service = new(
      language_name: "compiled",
      timeout_sec: timeout_sec,
      memory_limit_mb: memory_limit_mb,
      source_file: compiled_file,
      input_file: input_file,
      output_file: output_file
    )

    service.execute_binary(compiled_file)
  end

  # Execute a compiled binary
  def execute_binary(binary_path)
    result = ExecutionResult.new
    start_time = Time.now

    command = build_nsjail_command_for_binary(binary_path)

    begin
      # Check if /usr/bin/time is available, otherwise fall back to wall-clock time
      time_binary = "/usr/bin/time"
      use_cpu_time = File.exist?(time_binary)

      if use_cpu_time
        # Use /usr/bin/time to measure CPU time and execute in one go
        # Format: %U = user CPU time, %S = system CPU time, %e = elapsed time, %x = exit status
        # /usr/bin/time writes to stderr, so we capture stderr separately
        # Use Open3 to properly handle stdout/stderr streams
        time_command = "#{time_binary} -f 'TIME_STATS:%U %S %e %x' #{command}"
        stdout_str, stderr_str, status = Open3.capture3(time_command)

        exit_code = status.exitstatus

        # Parse timing stats from stderr
        timing_stats = nil
        if stderr_str =~ /TIME_STATS:(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)/
          user_time = $1.to_f
          system_time = $2.to_f
          elapsed_time = $3.to_f
          exit_code_from_time = $4.to_i

          # Use exit code from /usr/bin/time if available (more reliable)
          exit_code = exit_code_from_time if exit_code_from_time != 0 || exit_code == 0

          # Use CPU time (user + system) in milliseconds - this is more accurate
          # as it measures actual CPU time used, not wall-clock time
          timing_stats = ((user_time + system_time) * 1000).to_i
        end

        # Store any stderr output (excluding timing info)
        if stderr_str.present? && !stderr_str.match(/TIME_STATS:/)
          result.stderr = stderr_str
        end
      else
        # Fallback: execute command normally and use wall-clock time
        stdout_str, stderr_str, status = Open3.capture3(command)
        exit_code = status.exitstatus

        if stderr_str.present?
          result.stderr = stderr_str
        end
      end

      result.exit_code = exit_code

      if use_cpu_time && timing_stats
        result.execution_time_ms = timing_stats
      else
        # Fallback: use wall-clock time (includes nsjail overhead)
        result.execution_time_ms = ((Time.now - start_time) * 1000).to_i
      end

      result.timed_out = (result.exit_code == 137 || result.exit_code == 124)
      result.oom_killed = (result.exit_code == 137)

      # Read output from file (the program's stdout is redirected to the output file inside nsjail)
      if File.exist?(@output_file)
        result.stdout = File.read(@output_file)
      end

    rescue => e
      result.stderr = "Execution error: #{e.message}"
      result.exit_code = 1
      # Use wall-clock time as fallback
      result.execution_time_ms = ((Time.now - start_time) * 1000).to_i
    end

    result
  end

  private

  # Build the complete nsjail command with all security flags
  def build_nsjail_command
    interpreter = get_interpreter_for_language

    # Build the inner command that will run inside nsjail
    inner_command = "#{interpreter} #{WORKSPACE_PATH}/source < #{WORKSPACE_PATH}/input > #{WORKSPACE_PATH}/output 2>&1"

    [
      NSJAIL_BINARY,
      "--quiet",                                    # Suppress nsjail messages
      "--chroot", CHROOT_PATH,                     # Chroot to isolated filesystem
      "--user", "65534",                           # Run as nobody user
      "--group", "65534",                          # Run as nobody group
      "--hostname", "NSJAIL",                      # Set hostname
      "--cwd", WORKSPACE_PATH,                     # Set working directory
      "--time_limit", @timeout_sec.to_s,          # Wall-time timeout
      "--max_cpus", "1",                           # Limit to 1 CPU
      "--rlimit_as", (@memory_limit_mb * 1024 * 1024).to_s,  # Memory limit (soft)
      "--rlimit_core", "0",                        # No core dumps
      "--rlimit_fsize", (MAX_FILE_SIZE_MB * 1024 * 1024).to_s,  # Max file size
      "--rlimit_nofile", MAX_FILE_DESCRIPTORS.to_s,  # Max file descriptors
      "--rlimit_nproc", MAX_PROCESSES.to_s,        # Max processes (prevent fork bombs)
      "--disable_proc",                            # Don't mount /proc
      "--iface_no_lo",                             # Disable loopback interface (no network)
      "--bindmount", "#{@source_file}:#{WORKSPACE_PATH}/source:ro",  # Mount source file (read-only)
      "--bindmount", "#{@input_file}:#{WORKSPACE_PATH}/input:ro",    # Mount input file (read-only)
      "--bindmount", "#{@output_file}:#{WORKSPACE_PATH}/output:rw",  # Mount output file (read-write)
      "--",                                        # End of nsjail args
      "/bin/sh", "-c", "\"#{inner_command.gsub('"', '\\"')}\""       # Shell to run command (escape double quotes)
    ].join(" ")
  end

  # Build nsjail command for compiled binary
  def build_nsjail_command_for_binary(binary_path)
    # Build the inner command that will run inside nsjail
    inner_command = "#{WORKSPACE_PATH}/program < #{WORKSPACE_PATH}/input > #{WORKSPACE_PATH}/output 2>&1"

    [
      NSJAIL_BINARY,
      "--quiet",
      "--chroot", CHROOT_PATH,
      "--user", "65534",
      "--group", "65534",
      "--hostname", "NSJAIL",
      "--cwd", WORKSPACE_PATH,
      "--time_limit", @timeout_sec.to_s,
      "--max_cpus", "1",
      "--rlimit_as", (@memory_limit_mb * 1024 * 1024).to_s,
      "--rlimit_core", "0",
      "--rlimit_fsize", (MAX_FILE_SIZE_MB * 1024 * 1024).to_s,
      "--rlimit_nofile", MAX_FILE_DESCRIPTORS.to_s,
      "--rlimit_nproc", MAX_PROCESSES.to_s,
      "--disable_proc",
      "--iface_no_lo",
      "--bindmount", "#{binary_path}:#{WORKSPACE_PATH}/program:ro",
      "--bindmount", "#{@input_file}:#{WORKSPACE_PATH}/input:ro",
      "--bindmount", "#{@output_file}:#{WORKSPACE_PATH}/output:rw",
      "--",
      "/bin/sh", "-c", "\"#{inner_command.gsub('"', '\\"')}\""       # Shell to run command (escape double quotes)
    ].join(" ")
  end

  # Get interpreter path for language
  def get_interpreter_for_language
    lang = @language_name.downcase

    # Handle Python variations
    if lang.include?("python")
      return "/usr/bin/python3"
    end

    # Handle Ruby
    if lang == "ruby"
      return "/usr/bin/ruby"
    end

    # Handle JavaScript/Node.js variations (including "javascript (nodejs)", "node", "nodejs", etc.)
    if lang.include?("javascript") || lang.include?("node")
      return "/usr/bin/node"
    end

    raise "Unsupported language: #{@language_name}"
  end

  # Execute command and return exit code
  def execute_command(command)
    # Use system() to execute and get exit code
    system(command)
    $?.exitstatus
  end

end
