class User < ApplicationRecord
  belongs_to :customer

  class << self
    def ROLES
      ["admin", "user", "guest"]
    end
  end
end
