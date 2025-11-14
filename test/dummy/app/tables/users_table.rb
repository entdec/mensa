# frozen_string_literal: true

class UsersTable < Mensa::Base
  definition do
    model User

    render do
      html
      xlsx
    end

    column(:first_name)
    column(:last_name)
    column(:email)
    column(:role) do
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

    # view :default do
    #   name "All Users"
    # end
  end

  private

  def scope
    User.all.left_outer_joins(:customer)
  end
end
