# frozen_string_literal: true

class HeaderlessUsersTable < Mensa::Base
  model User

  column(:first_name)
  column(:last_name)
  column(:email)

  link { |user| edit_user_path(user) }

  supports_views true
  show_header false

  scope do
    User.all
  end
end
