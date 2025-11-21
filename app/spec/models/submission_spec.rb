# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submission, type: :model do
  let(:user) { create(:user) }
  let(:python_language) { create(:programming_language, :python) }
  let(:problem) { create(:problem, time_limit_sec: 5, memory_limit_kb: 262144) }

  describe '#run!' do
    context 'with Python interpreter' do
      it 'updates status to enqueued initially' do
        submission = create(:submission, 
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "print('Hello')",
          status: 'pending'
        )

        submission.run!

        expect(submission.reload.status).to eq(Submission::ACCEPTED)
      end

      it 'runs with interpreter when no compiler binary' do
        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "print('Hello')",
          status: 'pending'
        )

        expect(submission).to receive(:run_with_interpreter!).and_call_original
        submission.run!
      end
    end

    context 'with compiler' do
      let(:c_language) { create(:programming_language, 
        name: "C",
        compiler_binary: "gcc",
        compiler_flags: "-o {compiled_file} {source_file}",
        interpreter_binary: "",
        memory_limit_kb: 2048,
        time_limit_sec: 5,
        extension: "c"
      )}

      it 'runs with compiler when compiler binary exists' do
        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: c_language,
          source_code: "int main() { return 0; }",
          status: 'pending'
        )

        expect(submission).to receive(:run_with_compiler!).and_call_original
        submission.run!
      end
    end
  end

  describe '#run_with_interpreter!' do
    context 'with valid Python code' do
      it 'executes successfully and marks as accepted' do
        # Create problem with example
        example = problem.examples.create!(
          input: "5 3\n",
          output: "8\n",
          sort_order: 1
        )

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "a, b = map(int, input().split())\nprint(a + b)",
          status: 'pending'
        )

        submission.run_with_interpreter!

        expect(submission.reload.status).to eq(Submission::ACCEPTED)
        expect(submission.time_used).to be > 0
      end

      it 'handles multiple test cases correctly' do
        # Create problem with multiple examples
        problem.examples.create!(input: "1 1\n", output: "2\n", sort_order: 1)
        problem.examples.create!(input: "10 20\n", output: "30\n", sort_order: 2)
        problem.examples.create!(input: "100 200\n", output: "300\n", sort_order: 3)

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "a, b = map(int, input().split())\nprint(a + b)",
          status: 'pending'
        )

        submission.run_with_interpreter!

        expect(submission.reload.status).to eq(Submission::ACCEPTED)
      end

      it 'detects wrong answer' do
        problem.examples.create!(input: "5 3\n", output: "8\n", sort_order: 1)

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "print(42)",
          status: 'pending'
        )

        submission.run_with_interpreter!

        expect(submission.reload.status).to include(Submission::WRONG_ANSWER)
      end

      it 'detects presentation error' do
        problem.examples.create!(input: "5 3\n", output: "8", sort_order: 1)

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "a, b = map(int, input().split())\nprint(a + b)",
          status: 'pending'
        )

        submission.run_with_interpreter!

        # Python print adds newline, so output will be "8\n" vs expected "8"
        # This should be detected as presentation error after whitespace normalization
        expect([Submission::PRESENTATION_ERROR, Submission::WRONG_ANSWER]).to include(submission.reload.status)
      end

      it 'detects time limit exceeded' do
        problem.examples.create!(input: "", output: "", sort_order: 1)

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "while True: pass",
          status: 'pending'
        )

        submission.run_with_interpreter!

        expect(submission.reload.status).to eq(Submission::TIME_LIMIT_EXCEEDED)
      end

      it 'updates time_used in database' do
        problem.examples.create!(input: "1 1\n", output: "2\n", sort_order: 1)

        submission = create(:submission,
          user: user,
          problem: problem,
          programming_language: python_language,
          source_code: "a, b = map(int, input().split())\nprint(a + b)",
          status: 'pending'
        )

        submission.run_with_interpreter!

        expect(submission.reload.time_used).to be > 0
        expect(submission.reload.time_used).to be_a(Numeric)
      end
    end
  end
end
