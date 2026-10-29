# frozen_string_literal: true

# A table that can only be built with params[:customer_id]: it looks up the
# customer when initialized and raises without it. Used to check that the
# params reach every place the table is rebuilt (filters, exports, views).
class CustomerUsersTable < Mensa::Base
  model User

  column(:first_name)
  column(:last_name)
  column(:email)
  column(:role) do
    filter do
      collection -> { User.ROLES }
    end
  end

  scope do
    customer.users
  end

  def initialize(config = {})
    super
    customer
  end

  def customer
    @customer ||= Customer.find(params.fetch(:customer_id))
  end
end
