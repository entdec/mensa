require "test_helper"
require "pry"

class NoValueFilterTable < Mensa::Base
  definition do
    model User

    column(:role) do
      filter do
        operator :current
      end
    end
  end
end

class FilterTest < ActiveSupport::TestCase
  test "we can initialize a filter" do
    t = CustomerTable.new({filters: {country: {value: "NL"}}})
    f = t.active_filters.first
    assert_equal :country, f.column.name
    assert_equal "NL", f.value
    assert_equal :equals, f.operator
  end

  test "we return that the table has filters" do
    t = TestTable.new({})
    assert t.filters?
  end

  test "we return filtered rows with no operator (equals)" do
    t = CustomerTable.new({filters: {country: {value: "NL"}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    assert t.filters?
    assert_equal 4, t.rows.size
  end

  test "we return filtered rows with contains operator" do
    t = CustomerTable.new({filters: {country: {value: "NL", operator: :contains}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    assert t.filters?
    assert_equal 4, t.rows.size
  end

  test "operator_without_value filters do not require a value" do
    t = NoValueFilterTable.new({filters: {role: {operator: :is_current}}})
    f = t.active_filters.first

    refute f.operator_with_value?
    assert_equal "Role Is current", f.to_s
  end
end
