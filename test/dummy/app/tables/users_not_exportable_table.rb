# frozen_string_literal: true

class UsersNotExportableTable < Mensa::Base
  model User
  exportable false

  column(:first_name)
  column(:last_name)
  column(:email)
end
