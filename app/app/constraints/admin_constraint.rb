# frozen_string_literal: true

# Rack constraint to restrict Sidekiq web UI to admin users only
class AdminConstraint
  def matches?(request)
    return false unless request.session.present?
    
    # Access Warden through the request to get the current user
    # This works because Devise uses Warden for authentication
    warden = request.env['warden']
    return false unless warden
    
    user = warden.user
    return false unless user
    
    user.admin?
  rescue StandardError => e
    Rails.logger.error("AdminConstraint error: #{e.message}")
    false
  end
end
