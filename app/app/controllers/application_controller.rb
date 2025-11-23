class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Helper methods for authorization
  def admin_user?
    current_user&.admin? || false
  end

  def contest_participant?(contest)
    return false unless current_user && contest
    contest.user_participating?(current_user)
  end

  def can_access_contest?(contest)
    return false unless current_user && contest
    access_service = ContestAccessService.new(contest, current_user)
    access_service.can_view?
  end
end
