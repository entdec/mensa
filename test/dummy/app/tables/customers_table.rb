# frozen_string_literal: true

class CustomersTable < Mensa::Base
  definition do
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
      end
    end
    column(:isin)
    column(:updated_at)

    link { |customer| edit_customer_path(customer) }

    supports_views true
  end
end
