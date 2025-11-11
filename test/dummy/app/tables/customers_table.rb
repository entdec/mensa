# frozen_string_literal: true

class CustomersTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:stock_symbol)
    column(:country)
    column(:isin)
    column(:updated_at)
  end
end
