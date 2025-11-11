# frozen_string_literal: true

class UsersTable < Mensa::Base
  definition do
    model User

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
          link_to user.customer.name, url_for(user.customer) if user.customer
        end
      end
    end

    link { |user| edit_user_path(user) }

    supports_views true
  end

  private

  def scope
    User.all.left_joins(:customer)
  end
end
