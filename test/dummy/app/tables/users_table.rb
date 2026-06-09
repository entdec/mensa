# frozen_string_literal: true

class UsersTable < Mensa::Base
  model User

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
  end
  column :customer_id do
    internal true
  end
  column(:customer_name) do
    attribute "customers.name"
    render do
      html do |user|
        # You should not use customer_path(user.customer) here, that causes additional queries.
        link_to user.customer_name, customer_path(user.customer_id) if user.customer_id
      end
    end
  end

  link { |user| edit_user_path(user) }

  supports_views true
  supports_custom_views true

  view :default do
    name "All users"
    description "All users"
  end

  view :users do
    name "Users"
    filter :role do
      operator :equals
      value "user"
    end
    hidden_columns [:role]
  end

  action :show do
    link { |user| user_path(user) }
    icon "fal fa-eye"
  end
  action :edit do
    link { |user| edit_user_path(user) }
    icon "fal fa-pencil"
  end
  action :delete do
    link { |user| user_path(user) }
    link_attributes { {data: {turbo: {confirm: "Are you sure?", method: :delete}}} }
    icon "fal fa-trash"
  end

  batch :confirm do
    description "Confirm users"
    process do |records|
      ConfirmUsersJob.perform_later(records)
    end
  end

  private

  def scope
    User.all.left_outer_joins(:customer)
  end
end
