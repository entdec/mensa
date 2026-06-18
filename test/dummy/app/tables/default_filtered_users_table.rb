# frozen_string_literal: true

class DefaultFilteredUsersTable < Mensa::Base
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
        # You should not use customer_path(user.customer) here, that causes additional queries.
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

  view :default do
    name "Audi users"
    description "Users with customer Audi"
    filter :customer_name do
      operator :is
      value "Audi"
    end
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

  scope do
    scope = User.all.left_outer_joins(:customer)
    scope = scope.where(customers: {name: params[:customer_name]}) if params[:customer_name]
    scope
  end
end
