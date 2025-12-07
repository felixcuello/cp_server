# frozen_string_literal: true

class LocaleController < ApplicationController
  # Switch user's locale preference
  # POST /locale/:locale
  def switch
    locale = params[:locale]
    
    if I18n.available_locales.map(&:to_s).include?(locale)
      # Store locale in session
      session[:locale] = locale
      
      # If user is logged in, save their preference to the database
      if current_user
        current_user.update(locale: locale)
      end
      
      # Redirect back to the page they came from, or home if no referrer
      redirect_back(fallback_location: root_path)
    else
      redirect_to root_path, alert: 'Invalid locale'
    end
  end
end
