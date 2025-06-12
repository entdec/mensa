# frozen_string_literal: true

class UsersTable < Mensa::Base

  definition do
    model User

    column(:first_name)
    column(:last_name)
    column(:email)
    column(:role) do
      filter do
        collection -> { User.ROLES }
      end
    end
    column(:customer_name) do
      attribute "customers.name"

    end

    supports_views true
  end

  private

  def scope
    User.all.left_joins(:customer)
  end

end
