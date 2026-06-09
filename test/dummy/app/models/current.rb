# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def user
    User.first
  end

  # Used for is current in tables
  def customer_name
    user.customer&.name
  end
end
