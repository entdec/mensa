# frozen_string_literal: true

class SearchOnlyUsersTable < Mensa::Base
  model User

  column(:first_name)
  column(:last_name)
  column(:email)

  link { |user| edit_user_path(user) }

  scope do
    User.all
  end
end
