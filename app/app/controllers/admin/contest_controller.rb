# frozen_string_literal: true

class Admin::ContestController < AdminController
  before_action :set_contest, only: [:show, :edit, :update, :destroy, :add_problem, :remove_problem]

  def index
    @contests = Contest.order(created_at: :desc)
  end

  def show
    @problems = @contest.problems.order(:id)
    @all_problems = Problem.order(:id)
  end

  def new
    @contest = Contest.new
  end

  def create
    @contest = Contest.new(contest_params)

    if @contest.save
      redirect_to admin_contest_path(@contest), notice: "Contest created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @contest.update(contest_params)
      redirect_to admin_contest_path(@contest), notice: "Contest updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @contest.problems.any?
      redirect_to admin_contests_path, alert: "Cannot delete contest with problems. Remove all problems first."
    else
      @contest.destroy
      redirect_to admin_contests_path, notice: "Contest deleted successfully."
    end
  end

  def add_problem
    problem = Problem.find(params[:problem_id])
    
    if @contest.problems.include?(problem)
      redirect_to admin_contest_path(@contest), alert: "Problem is already in this contest."
    else
      problem.update(contest: @contest)
      redirect_to admin_contest_path(@contest), notice: "Problem added to contest."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_contest_path(@contest), alert: "Problem not found."
  end

  def remove_problem
    problem = Problem.find(params[:problem_id])
    
    if problem.contest_id == @contest.id
      problem.update(contest: nil)
      redirect_to admin_contest_path(@contest), notice: "Problem removed from contest."
    else
      redirect_to admin_contest_path(@contest), alert: "Problem is not in this contest."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_contest_path(@contest), alert: "Problem not found."
  end

  def toggle_problem_visibility
    problem = Problem.find(params[:problem_id])
    problem.update(hidden: !problem.hidden)
    
    redirect_to admin_contest_path(problem.contest), notice: "Problem visibility toggled."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_contests_path, alert: "Problem not found."
  end

  private

  def set_contest
    @contest = Contest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_contests_path, alert: "Contest not found."
  end

  def contest_params
    params.require(:contest).permit(:name, :description, :rules, :start_time, :end_time, :penalty_minutes)
  end
end
