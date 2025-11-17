# frozen_string_literal: true

class UserController < AuthenticatedController
  def show
    @user = User.find_by(alias: params[:alias])
    if @user.nil?
      redirect_to problems_path, alert: "User not found"
      return
    end

    # Count problems solved by difficulty
    @easy_count = 0
    @medium_count = 0
    @hard_count = 0

    Submission.where(status: 'accepted', user: @user).joins(:problem).select('problems.id, problems.difficulty').distinct.each do |problem|
      @easy_count += 1 if problem.difficulty == Problem.difficulties[:easy]
      @medium_count += 1 if problem.difficulty == Problem.difficulties[:medium]
      @hard_count += 1 if problem.difficulty == Problem.difficulties[:hard]
    end

    # Total problems solved
    @total_solved = @easy_count + @medium_count + @hard_count
    
    # Total submissions
    @total_submissions = Submission.where(user: @user).count
    @accepted_submissions = Submission.where(user: @user, status: 'accepted').count
    
    # Programming languages used
    @programming_languages = Submission.where(user: @user)
                                       .joins(:programming_language)
                                       .select('programming_languages.name')
                                       .pluck(:name)
                                       .uniq
                                       .sort
    
    # Recent submissions (last 10)
    @recent_submissions = Submission.where(user: @user)
                                   .includes(:problem, :programming_language)
                                   .order(created_at: :desc)
                                   .limit(10)
    
    # Contribution calendar data (last 365 days)
    @contribution_data = generate_contribution_data(@user)
  end
  
  private
  
  def generate_contribution_data(user)
    # Get submissions from the last 365 days
    end_date = Date.today
    start_date = end_date - 364.days
    
    # Group submissions by date
    submissions_by_date = Submission.where(user: user)
                                   .where('created_at >= ?', start_date)
                                   .group('DATE(created_at)')
                                   .count
    
    # Convert to hash with date strings as keys
    contributions = {}
    (start_date..end_date).each do |date|
      date_key = date.to_s
      count = submissions_by_date[date] || 0
      contributions[date_key] = count
    end
    
    contributions
  end
end
