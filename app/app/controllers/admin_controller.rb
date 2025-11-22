# frozen_string_literal: true

class AdminController < AuthenticatedController
  before_action :ensure_admin!

  private

  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You don't have permission to access this page."
    end
  end
end
