# frozen_string_literal: true

class UserController < AuthenticatedController
  def show
    @user = User.find_by(alias: params[:alias])
    if @user.nil?
      redirect_to problems_path, alert: "User not found"
    end

    @easy_count = 0
    @medium_count = 0
    @hard_count = 0

    Submission.where(status: 'accepted', user: current_user).joins(:problem).select('problems.id, problems.difficulty').distinct.each do |problem|
      @easy_count += 1 if problem.difficulty == Problem.difficulties[:easy]
      @medium_count += 1 if problem.difficulty == Problem.difficulties[:medium]
      @hard_count += 1 if problem.difficulty == Problem.difficulties[:hard]
    end

    @programming_languages = Submission.where(status: 'accepted', user_id: 1).joins(:programming_language).select('programming_languages.name').pluck(:name).uniq
  end
end
