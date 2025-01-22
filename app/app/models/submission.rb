# frozen_string_literal: true

class Submission < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language
  belongs_to :user

  enum status: %i[
    queued
    running
    accepted
    compilation_error
    memory_limit_exceeded
    runtime_error
    time_limit_exceeded
    wrong_answer
  ]

  validates :source_code, presence: true
end
