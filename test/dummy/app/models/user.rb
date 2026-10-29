class User < ApplicationRecord
  belongs_to :customer

  class << self
    def ROLES
      [[I18n.t("activerecord.constants.user.roles.admin"), "admin"],
        [I18n.t("activerecord.constants.user.roles.user"), "user"],
        [I18n.t("activerecord.constants.user.roles.guest"), "guest"]]
    end
  end
end
