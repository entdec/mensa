# frozen_string_literal: true

class SearchOnlyUsersTable < Mensa::Base
  model User

  column(:first_name) do
    filter false
  end

  column(:last_name) do
    filter false
  end

  column(:email) do
    filter false
  end

  link { |user| edit_user_path(user) }

  scope do
    User.all
  end
end
