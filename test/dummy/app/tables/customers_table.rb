# frozen_string_literal: true

class CustomersTable < Mensa::Base
  model Customer

  column(:name)
  column(:industry) do
    filter do
      collection -> { Customer.pluck(:industry).uniq.compact.sort }
    end
  end
  column(:stock_symbol)
  column(:country) do
    filter do
      collection -> { Customer.pluck(:country).uniq }
      multiple true
    end
  end
  column(:isin)
  column(:number_of_employees)
  column(:market_cap)
  column(:users_count) do
    attribute "COUNT(DISTINCT users.id)"
    type :integer
    filter do
      having true
    end
  end
  column(:created_at)
  column(:updated_at)

  link { |customer| edit_customer_path(customer) }

  view :de do
    name "Germany"
    filter :country do
      operator :is
      value "DE"
    end
  end

  scope do
    Customer.joins(:users).group(:id)
  end
end
