# frozen_string_literal: true

class CustomersTable < Mensa::Base

  definition do
    model Customer

    column(:name)
    column(:updated_at)
  end
end
