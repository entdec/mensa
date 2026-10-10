# frozen_string_literal: true

class CustomersTable < Mensa::Base
  model Customer

  column(:name)
  column(:industry) do
    groupable true
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
    groupable true
  end
  column(:isin)
  column(:number_of_employees) do
    aggregates :sum, :min, :max
  end
  column(:market_cap) do
    aggregates :sum, :min, :max
  end
  column(:users_count) do
    attribute "COUNT(DISTINCT users.id)"
    type :integer
    aggregates :sum, :max
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
