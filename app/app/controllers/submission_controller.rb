# frozen_string_literal: true

class SubmissionController < ApplicationController
  def index
    @submissions = Submission.all
  end
end
