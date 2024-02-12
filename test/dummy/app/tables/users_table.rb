# frozen_string_literal: true

class UsersTable < Mensa::Base

  definition do
    model User

    column(:first_name)
    column(:last_name)
    column(:email)
  end
end
