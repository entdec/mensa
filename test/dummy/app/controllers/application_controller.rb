class ApplicationController < ActionController::Base
  before_action :set_locale

  def set_locale
    I18n.locale = params[:locale]&.to_sym || session[:locale]&.to_sym || :en
    session[:locale] = I18n.locale
  end

  def current_user
    @current_user ||= User.first
  end
  helper_method :current_user
end
