class ApplicationController < ActionController::Base
  include Mensa::TableNavigation

  before_action :set_locale_and_timezone

  def set_locale_and_timezone
    I18n.locale = params[:locale]&.to_sym || session[:locale]&.to_sym || :en
    Time.zone = params[:time_zone]&.to_sym || session[:time_zone]&.to_sym || "Amsterdam"
    session[:locale] = I18n.locale
  end

  def current_user
    @current_user ||= User.first
  end
  helper_method :current_user
end
