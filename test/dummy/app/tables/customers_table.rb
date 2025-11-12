# frozen_string_literal: true

class CustomersTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:stock_symbol)
    column(:country)
    column(:isin)
    column(:updated_at)

    link { |customer| edit_customer_path(customer) }

    supports_views true
  end
end
