# frozen_string_literal: true

class ProblemController < AuthenticatedController
  before_action :difficulty, only: %i[index]

  def index
    @problems = Problem.includes(:tags)

    if params[:tag]
      @problems = @problems.where(tags: { name: params[:tag] })
    elsif params[:difficulty]
      @problems = @problems.where(difficulty: @difficulty)
    end
  end

  def show
    @problem = Problem.find(params[:id])
    @languages = ProgrammingLanguage.order(:name)
  end

  private

  def difficulty
    @difficulty = params[:difficulty].to_sym if params[:difficulty]
  end
end
