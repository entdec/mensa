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
  column(:created_at)
  column(:updated_at)

  link { |customer| edit_customer_path(customer) }

  supports_custom_views true

  view :de do
    name "Germany"
    filter :country do
      operator :is
      value "DE"
    end
  end

  scope do
    Customer.all
  end
end
