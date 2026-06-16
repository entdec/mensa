# frozen_string_literal: true

class UsersExportWithPasswordTable < Mensa::Base
  model User
  export_with_password true

  render do
    html
    csv
  end

  column(:first_name)
  column(:last_name)
  column(:email)
  column(:role) do
    sortable false
    filter do
      collection -> { User.ROLES }
    end
    render do
      html do |user|
        User.ROLES.find { |_, role| role == user.role }&.first
      end
    end
  end
  column(:customer_name) do
    attribute "customers.name"
    render do
      html do |user|
        link_to user.customer_name, customer_path(user.customer_id) if user.customer_id
      end
    end
    filter do
      collection -> { Customer.select(:name).order(:name).pluck(:name) }
    end
  end
  column(:created_at)
  column(:updated_at)

  link { |user| edit_user_path(user) }

  scope do
    User.all.left_outer_joins(:customer)
  end
end
