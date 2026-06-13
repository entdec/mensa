# frozen_string_literal: true

class NonCustomViewUsersTable < Mensa::Base
  model User

  column(:first_name)
  column(:last_name)
  column(:role) do
    sortable false
    filter do
      collection -> { User.ROLES }
    end
  end

  link { |user| edit_user_path(user) }

  supports_views true

  scope do
    User.all
  end
end
