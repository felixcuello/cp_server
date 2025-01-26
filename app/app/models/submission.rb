# frozen_string_literal: true

class Submission < ApplicationRecord
  belongs_to :problem
  belongs_to :programming_language
  belongs_to :user

  validates :source_code, presence: true
  validates :status, presence: true
end
