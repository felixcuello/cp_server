# frozen_string_literal: true

class ProblemController < AuthenticatedController
  def index
    @problems = Problem.all
  end

  def show
    @problem = Problem.find(params[:id])
  end
end
