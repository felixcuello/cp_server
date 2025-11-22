# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NsjailExecutionService do
  let(:timeout_sec) { 5 }
  let(:memory_limit_mb) { 256 }

  # Helper to check if nsjail execution environment is available
  def nsjail_available?
    chroot_path = NsjailExecutionService::CHROOT_PATH
    nsjail_binary = NsjailExecutionService::NSJAIL_BINARY
    Dir.exist?(chroot_path) && File.exist?(nsjail_binary) && File.executable?(nsjail_binary)
  end

  before do
    @temp_dir = Dir.mktmpdir
    @source_file = File.join(@temp_dir, "source.py")
    @input_file = File.join(@temp_dir, "input.txt")
    @output_file = File.join(@temp_dir, "output.txt")
  end

  after do
    FileUtils.rm_rf(@temp_dir)
  end

  describe '#execute' do
    context 'with valid Python code' do
      it 'executes successfully and returns output' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?

        File.write(@source_file, "print(input())")
        File.write(@input_file, "Hello World")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.success?).to be true
        expect(result.stdout.strip).to eq("Hello World")
        expect(result.timed_out).to be false
      end
    end

    context 'with simple arithmetic' do
      it 'executes Python code with calculations' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?
        File.write(@source_file, "a, b = map(int, input().split())\nprint(a + b)")
        File.write(@input_file, "5 3")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.success?).to be true
        expect(result.stdout.strip).to eq("8")
        expect(result.timed_out).to be false
      end
    end

    context 'with infinite loop' do
      it 'times out correctly' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?

        File.write(@source_file, "while True: pass")
        File.write(@input_file, "")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: 1,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.timed_out).to be true
      end
    end

    context 'with memory-intensive code' do
      it 'respects memory limits' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?
        File.write(@source_file, "a = [0] * (1024 * 1024 * 1024)")  # Try to allocate 1GB
        File.write(@input_file, "")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: 50,  # Only 50MB allowed
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        # Should fail due to memory limits
        expect(result.success?).to be false
      end
    end

    context 'with runtime error' do
      it 'detects errors correctly' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?

        File.write(@source_file, "print(1/0)")  # Division by zero
        File.write(@input_file, "")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.success?).to be false
        expect(result.exit_code).not_to eq(0)
      end
    end

    context 'with empty input' do
      it 'handles empty input correctly' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?
        File.write(@source_file, "print('Hello')")
        File.write(@input_file, "")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.success?).to be true
        expect(result.stdout.strip).to eq("Hello")
      end
    end

    context 'with multiple lines of output' do
      it 'captures all output lines' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?

        File.write(@source_file, "for i in range(5):\n    print(i)")
        File.write(@input_file, "")
        File.write(@output_file, "")

        service = described_class.new(
          language_name: "Python 3",
          timeout_sec: timeout_sec,
          memory_limit_mb: memory_limit_mb,
          source_file: @source_file,
          input_file: @input_file,
          output_file: @output_file
        )

        result = service.execute

        expect(result.success?).to be true
        expect(result.stdout.strip).to eq("0\n1\n2\n3\n4")
      end
    end
  end

  describe '.execute_compiled' do
    context 'with a compiled binary' do
      it 'executes binary successfully' do
        skip "nsjail/chroot not available in test environment" unless nsjail_available?

        # Create a simple C program
        c_source = File.join(@temp_dir, "test.c")
        File.write(c_source, <<~C)
          #include <stdio.h>
          int main() {
              int a, b;
              scanf("%d %d", &a, &b);
              printf("%d\\n", a + b);
              return 0;
          }
        C

        # Compile it
        binary_file = File.join(@temp_dir, "test")
        compile_result = system("gcc #{c_source} -o #{binary_file} 2>/dev/null")

        if compile_result
          File.write(@input_file, "10 20")
          File.write(@output_file, "")

          result = described_class.execute_compiled(
            timeout_sec: timeout_sec,
            memory_limit_mb: memory_limit_mb,
            compiled_file: binary_file,
            input_file: @input_file,
            output_file: @output_file
          )

          expect(result.success?).to be true
          expect(result.stdout.strip).to eq("30")
        else
          skip "GCC not available in test environment"
        end
      end
    end
  end

  describe 'ExecutionResult' do
    it 'initializes with default values' do
      result = NsjailExecutionService::ExecutionResult.new

      expect(result.exit_code).to be_nil
      expect(result.stdout).to eq("")
      expect(result.stderr).to eq("")
      expect(result.timed_out).to be false
      expect(result.oom_killed).to be false
      expect(result.execution_time_ms).to eq(0)
    end

    it 'returns true for success? when exit_code is 0' do
      result = NsjailExecutionService::ExecutionResult.new
      result.exit_code = 0

      expect(result.success?).to be true
    end

    it 'returns false for success? when exit_code is not 0' do
      result = NsjailExecutionService::ExecutionResult.new
      result.exit_code = 1

      expect(result.success?).to be false
    end
  end

  describe '#get_interpreter_for_language' do
    it 'returns correct interpreter for Python' do
      service = described_class.new(
        language_name: "Python 3",
        timeout_sec: 1,
        memory_limit_mb: 100,
        source_file: "/tmp/test.py",
        input_file: "/tmp/in.txt",
        output_file: "/tmp/out.txt"
      )

      interpreter = service.send(:get_interpreter_for_language)
      expect(interpreter).to eq("/usr/bin/python3")
    end

    it 'returns correct interpreter for Ruby' do
      service = described_class.new(
        language_name: "Ruby",
        timeout_sec: 1,
        memory_limit_mb: 100,
        source_file: "/tmp/test.rb",
        input_file: "/tmp/in.txt",
        output_file: "/tmp/out.txt"
      )

      interpreter = service.send(:get_interpreter_for_language)
      expect(interpreter).to eq("/usr/bin/ruby")
    end

    it 'returns correct interpreter for Node.js' do
      service = described_class.new(
        language_name: "Node.js",
        timeout_sec: 1,
        memory_limit_mb: 100,
        source_file: "/tmp/test.js",
        input_file: "/tmp/in.txt",
        output_file: "/tmp/out.txt"
      )

      interpreter = service.send(:get_interpreter_for_language)
      expect(interpreter).to eq("/usr/bin/node")
    end

    it 'raises error for unsupported language' do
      service = described_class.new(
        language_name: "Brainfuck",
        timeout_sec: 1,
        memory_limit_mb: 100,
        source_file: "/tmp/test.bf",
        input_file: "/tmp/in.txt",
        output_file: "/tmp/out.txt"
      )

      expect {
        service.send(:get_interpreter_for_language)
      }.to raise_error("Unsupported language: Brainfuck")
    end
  end
end
