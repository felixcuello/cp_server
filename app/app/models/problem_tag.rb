# frozen_string_literal: true

class ProblemTag < ApplicationRecord
  belongs_to :problem
  belongs_to :tag
end
