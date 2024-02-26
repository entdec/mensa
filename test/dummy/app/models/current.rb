# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def user
    User.first
  end
end