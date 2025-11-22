# frozen_string_literal: true

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

    # Execute with timeout
    begin
      # Run the command and capture output
      exit_code = execute_command(command)

      result.exit_code = exit_code
      result.execution_time_ms = ((Time.now - start_time) * 1000).to_i

      # Check for specific error conditions
      result.timed_out = (exit_code == 137 || exit_code == 124) # SIGKILL or timeout
      result.oom_killed = (exit_code == 137) # Could also be OOM

      # Read output if file exists
      if File.exist?(@output_file)
        result.stdout = File.read(@output_file)
      end

    rescue => e
      result.stderr = "Execution error: #{e.message}"
      result.exit_code = 1
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
      exit_code = execute_command(command)

      result.exit_code = exit_code
      result.execution_time_ms = ((Time.now - start_time) * 1000).to_i
      result.timed_out = (exit_code == 137 || exit_code == 124)
      result.oom_killed = (exit_code == 137)

      if File.exist?(@output_file)
        result.stdout = File.read(@output_file)
      end

    rescue => e
      result.stderr = "Execution error: #{e.message}"
      result.exit_code = 1
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
    case @language_name.downcase
    when "python", "python3", "python 3"
      "/usr/bin/python3"
    when "ruby"
      "/usr/bin/ruby"
    when "javascript", "node", "nodejs", "node.js"
      "/usr/bin/node"
    else
      raise "Unsupported language: #{@language_name}"
    end
  end

  # Execute command and return exit code
  def execute_command(command)
    # Use system() to execute and get exit code
    system(command)
    $?.exitstatus
  end
end
