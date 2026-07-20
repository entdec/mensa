require "test_helper"
require "pry"

class NoValueFilterTable < Mensa::Base
  definition do
    model User

    column(:role) do
      filter do
        operator :is_current
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
    assert_equal :is, f.operator
  end

  test "we return that the table has filters" do
    t = TestTable.new({})
    assert t.filters?
  end

  test "we return filtered rows with no operator (is)" do
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

  test "operator_without_value filters do not require a value" do
    t = NoValueFilterTable.new({filters: {role: {operator: :is_current}}})
    f = t.active_filters.first

    assert_not f.operator_with_value?
    assert_equal "Role is current", f.to_s
  end

  test "is_duplicate filters rows with duplicate values" do
    customer = customers(:asml)

    User.create!(email: "duplicate@mensa.test", first_name: "A", last_name: "A", role: "user", customer: customer)
    User.create!(email: "duplicate@mensa.test", first_name: "B", last_name: "B", role: "user", customer: customer)
    User.create!(email: "unique@mensa.test", first_name: "C", last_name: "C", role: "user", customer: customer)

    t = UsersTable.new({filters: {email: {operator: :is_duplicate}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))

    duplicate_emails = t.ordered_scope.pluck(:email).sort
    assert_equal ["duplicate@mensa.test", "duplicate@mensa.test"], duplicate_emails

    f = t.active_filters.first
    assert_not f.operator_with_value?
    assert_equal "Email is duplicate", f.to_s
  end

  test "is_duplicate is evaluated within current scope" do
    asml = customers(:asml)
    sap = customers(:sap)

    User.create!(email: "scoped-duplicate@mensa.test", first_name: "A", last_name: "A", role: "user", customer: asml)
    User.create!(email: "scoped-duplicate@mensa.test", first_name: "B", last_name: "B", role: "user", customer: sap)

    t = UsersTable.new({params: {customer_name: "ASML"}, filters: {email: {operator: :is_duplicate}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))

    assert_empty t.ordered_scope.pluck(:email)
  end

  test "raises ArgumentError when an unknown operator is configured via DSL" do
    t = CustomerTable.new({filters: {country: {value: "NL", operator: :nonexistent}}})
    error = assert_raises(ArgumentError) { t.active_filters }
    assert_match(/Unknown filter operator/, error.message)
    assert_match(/:nonexistent/, error.message)
  end

  test "raises ArgumentError when an unknown operator is listed in the operators DSL option" do
    t = CustomerTable.new({filters: {country: {value: "NL", operators: [:is, :fake_operator]}}})
    error = assert_raises(ArgumentError) { t.active_filters }
    assert_match(/Unknown filter operator/, error.message)
    assert_match(/:fake_operator/, error.message)
  end
end
