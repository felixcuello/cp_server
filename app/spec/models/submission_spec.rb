# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submission, type: :model do
  let(:submission) { create(:submission) }

  describe '#run!' do
  end

  # describe '#run!' do
  #   it 'updates the status to enqueued' do
  #     submission.run!

  #     expect(submission.status).to eq(Submission::ENQUEUED)
  #   end

  #   context 'when the programming language has a compiler binary' do
  #     it 'runs with the compiler' do
  #       submission.programming_language.update!(compiler_binary: 'gcc')

  #       expect(submission).to receive(:run_with_compiler!)

  #       submission.run!
  #     end
  #   end

  #   context 'when the programming language does not have a compiler binary' do
  #     it 'runs with the interpreter' do
  #       submission.programming_language.update!(compiler_binary: '')

  #       expect(submission).to receive(:run_with_interpreter!)

  #       submission.run!
  #     end
  #   end
  # end

  # describe '#run_with_interpreter!' do
  #   it 'updates the status to running' do
  #     submission.run_with_interpreter!

  #     expect(submission.status).to eq(Submission::RUNNING)
  #   end

  #   it 'runs the examples' do
  #     submission.run_with_interpreter!

  #     expect(submission.status).to eq(Submission::ACCEPTED)
  #   end
  # end
end
