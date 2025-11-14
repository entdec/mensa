require "test_helper"
require "pry"

class FilterTest < ActiveSupport::TestCase
  test "we can initialize a filter" do
    t = CustomerTable.new({filters: {country: {value: "NL"}}})
    f = t.column(:country).filter
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

  test "we return filtered rows with matches operator" do
    t = CustomerTable.new({filters: {country: {value: "NL", operator: :matches}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    assert t.filters?
    assert_equal 4, t.rows.size
  end
end
