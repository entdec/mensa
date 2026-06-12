require "test_helper"

class SearchAliasTable < Mensa::Base
  definition do
    model User

    column(:full_name) do
      attribute "CONCAT(first_name, ' ', last_name)"
    end
  end
end

class SearchCustomerTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:number_of_employees)
    column(:created_at)
  end
end

class SearchTest < ActiveSupport::TestCase
  test "searches joined selected columns" do
    table = UsersTable.new(query: "SAP")

    assert_equal [users(:sap_user).id], table.filtered_scope.pluck(:id)
  end

  test "searches integer and datetime selected columns by casting to text" do
    customer = Customer.create!(
      name: "Searchable Corp",
      country: "NL",
      industry: "Tech",
      stock_symbol: "SRC",
      isin: "NL0000000001",
      number_of_employees: 12_345,
      created_at: Time.zone.parse("2024-01-15 12:34:56"),
      updated_at: Time.zone.parse("2024-01-15 12:34:56")
    )

    integer_table = SearchCustomerTable.new(query: "12345")
    datetime_table = SearchCustomerTable.new(query: "2024-01-15")

    assert_includes integer_table.filtered_scope.pluck(:id), customer.id
    assert_includes datetime_table.filtered_scope.pluck(:id), customer.id
  end

  test "fuzzy search uses pg_trgm similarity scoring across all selected columns" do
    original_search = Mensa.config.search
    Mensa.config.search = :fuzzy

    table = UsersTable.new(query: "sap")
    table.singleton_class.define_method(:pg_trgm_enabled?) { |_record_scope| true }

    sql = table.ordered_scope.to_sql

    assert_includes sql, "similarity(CONCAT_WS"
    assert_includes sql, "AS mensa_search_score"
    assert_includes sql, "ORDER BY similarity("
    assert_includes sql, "customers.name"
    assert_includes sql, "users.created_at"
  ensure
    Mensa.config.search = original_search
  end

  test "configured attributes can include an alias without duplicating it" do
    column = SearchAliasTable.new({}).column(:full_name)

    assert_equal "CONCAT(first_name, ' ', last_name) AS full_name", column.attribute
    assert_equal "CONCAT(first_name, ' ', last_name)", column.raw_attribute
    assert_equal "CONCAT(first_name, ' ', last_name)", column.attribute_for_condition
  end
end
