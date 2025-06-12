# frozen_string_literal: true

Satis.setup do |config|
  config.submit_on_enter = false

  config.logger = Rails.logger
  config.confirm_before_leave = false
  config.current_user = -> { Current.user }

  config.default_help_text = lambda do |template, object, key, additional_scope|
    return if object.blank?

    I18n.t(["help", object.model_name.singular, key.to_s].join("."), default: nil)
  end
end
