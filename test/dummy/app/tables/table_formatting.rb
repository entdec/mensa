# frozen_string_literal: true

# Not a table: a helper living next to the tables, which Mensa::Verifier
# reports as skipped.
module TableFormatting
  def self.money(cents)
    format("%.2f", cents / 100.0)
  end
end
