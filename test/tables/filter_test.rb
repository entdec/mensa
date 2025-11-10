require "test_helper"
require 'pry'

class FilterTest < ActiveSupport::TestCase
  test "we return that the table has filters" do
    t = TestTable.new({})
    assert t.filters?
  end
  test "we return filtered rows" do
    t = CustomerTable.new({filters:{country: {value: 'NL', operator: :matches}} })
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    assert t.filters?
    assert_equal 4, t.rows.size
  end
end
