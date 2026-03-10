# frozen_string_literal: true

class LeaderboardController < AuthenticatedController
  def index
    @top_users = top_solvers
    @problems = sorted_problems
  end

  private

  def top_solvers
    User.joins(:user_problem_statuses)
        .where(user_problem_statuses: { status: "solved" })
        .where.not(role: User.roles[:admin])
        .group("users.id")
        .select("users.*, COUNT(user_problem_statuses.id) AS problems_solved_count")
        .order(Arel.sql("COUNT(user_problem_statuses.id) DESC"))
        .limit(10)
  end

  def sorted_problems
    scope = Problem.visible_to_user(current_user).where("total_submissions >= 1")

    acceptance_order = if params[:problem_sort] == "acceptance_desc"
                         "(accepted_submissions * 1.0) / NULLIF(total_submissions, 0) DESC"
                       else
                         "(accepted_submissions * 1.0) / NULLIF(total_submissions, 0) ASC"
                       end

    scope.order(Arel.sql(acceptance_order), title: :asc)
  end
end
