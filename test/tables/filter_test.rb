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

class CustomerFilterTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:country) do
      filter
    end
    column(:isin) do
      filter
    end
    column(:number_of_employees) do
      filter
    end
    column(:country_code) do
      attribute "LOWER(customers.country)"
      filter
    end
  end
end

class CustomScopeFilterTable < Mensa::Base
  definition do
    model Customer

    column(:name) do
      filter do
        collection -> { %w[NL DE FR] }
        operators [:is, :isnt]
        operator :isnt
        multiple true
        # Filters on country even though the column shows the name, so the
        # default `(customers.name) = value` comparison would match nothing.
        scope ->(value) { where(country: value) }
      end
    end
    column(:country) do
      filter do
        operators [:is, :isnt, :is_empty]
        scope ->(value, operator) {
          case operator
          when :isnt then where.not(country: value)
          when :is_empty then where(country: nil)
          else where(country: value)
          end
        }
      end
    end
    column(:stock_symbol) do
      filter do
        scope proc { |value| where(country: value) }
      end
    end
  end
end

class InvalidOperatorsFilterTable < Mensa::Base
  definition do
    model Customer

    column(:country) do
      filter do
        operators [:is, :fake_operator]
      end
    end
  end
end

class FilterTest < ActiveSupport::TestCase
  def filtered_scope(filters)
    t = CustomerFilterTable.new({filters: filters})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    t.ordered_scope
  end

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

  test "is_current filters on the Current attribute named after the column" do
    t = UsersTable.new({filters: {customer_name: {operator: :is_current}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    expected = User.left_outer_joins(:customer).where(customers: {name: Current.customer_name})

    assert Current.customer_name.present?
    assert_equal expected.pluck(:id).sort, t.ordered_scope.pluck(:id).sort
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
    t = InvalidOperatorsFilterTable.new({filters: {country: {value: "NL"}}})
    error = assert_raises(ArgumentError) { t.active_filters }
    assert_match(/Unknown filter operator/, error.message)
    assert_match(/:fake_operator/, error.message)
  end

  test "filters compare against the column, not a quoted string literal" do
    sql = filtered_scope({country: {value: "NL"}}).to_sql

    assert_match(/\("customers"\."country"\) = 'NL'/, sql)
    assert_no_match(/'"customers"\."country"'/, sql)
  end

  test "isnt operator excludes matching rows" do
    assert_equal Customer.where.not(country: "NL").count, filtered_scope({country: {value: "NL", operator: :isnt}}).count
  end

  test "does_not_match operator excludes matching rows" do
    assert_equal Customer.where.not(country: "NL").count, filtered_scope({country: {value: "NL", operator: :does_not_match}}).count
  end

  test "is_empty operator returns rows with a blank value" do
    Customer.find_by!(name: "SAP").update!(isin: "")

    assert_equal 3, filtered_scope({isin: {operator: :is_empty}}).count
  end

  test "isnt_empty operator returns rows with a value" do
    Customer.find_by!(name: "SAP").update!(isin: "")

    assert_equal Customer.count - 3, filtered_scope({isin: {operator: :isnt_empty}}).count
  end

  test "comparison operators filter on the column value" do
    Customer.update_all(number_of_employees: 10)
    Customer.where(country: "NL").update_all(number_of_employees: 1000)

    assert_equal 4, filtered_scope({number_of_employees: {value: 100, operator: :gt}}).count
    assert_equal 4, filtered_scope({number_of_employees: {value: 1000, operator: :gteq}}).count
    assert_equal Customer.count - 4, filtered_scope({number_of_employees: {value: 100, operator: :lt}}).count
    assert_equal Customer.count - 4, filtered_scope({number_of_employees: {value: 10, operator: :lteq}}).count
  end

  test "filters work on columns with a custom attribute expression" do
    assert_equal 4, filtered_scope({country_code: {value: "nl"}}).count
    assert_equal Customer.count - 4, filtered_scope({country_code: {value: "nl", operator: :isnt}}).count
  end

  test "is operator with multiple values matches any of them" do
    assert_equal Customer.where(country: %w[NL DE]).count, filtered_scope({country: {value: %w[NL DE]}}).count
  end

  test "isnt operator with multiple values excludes all of them" do
    assert_equal Customer.where.not(country: %w[NL DE]).count, filtered_scope({country: {value: %w[NL DE], operator: :isnt}}).count
  end

  test "blank entries in multiple values are ignored" do
    assert_equal Customer.where(country: "NL").count, filtered_scope({country: {value: ["", "NL"]}}).count
  end

  test "multiple values with nothing selected do not filter" do
    assert_equal Customer.count, filtered_scope({country: {value: [""]}}).count
    assert_equal Customer.count, filtered_scope({country: {value: [], operator: :isnt}}).count
  end

  test "having filters filter on the aggregate expression" do
    asml = customers(:asml)
    User.create!(email: "extra-1@mensa.test", first_name: "A", last_name: "A", role: "user", customer: asml)
    User.create!(email: "extra-2@mensa.test", first_name: "B", last_name: "B", role: "user", customer: asml)

    t = CustomersTable.new({filters: {users_count: {value: 1, operator: :gt}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    scope = t.ordered_scope

    assert_match(/HAVING \(+COUNT\(DISTINCT users\.id\)\) > 1/, scope.to_sql)
    assert_equal [asml.id], scope.pluck(:id)
  end

  test "is_duplicate on a having filter compares the aggregate per group" do
    counts = Customer.joins(:users).group(:id).count("DISTINCT users.id")
    duplicates = counts.values.tally.select { |_count, times| times > 1 }.keys
    assert duplicates.any?, "fixtures need customers with the same number of users"

    t = CustomersTable.new({filters: {users_count: {operator: :is_duplicate}}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))

    assert_equal counts.select { |_id, count| duplicates.include?(count) }.keys.sort, t.ordered_scope.pluck(:id).sort
  end

  def custom_scope_table(filters)
    t = CustomScopeFilterTable.new({filters: filters})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    t
  end

  test "a custom filter scope is applied with a single value" do
    scope = custom_scope_table({name: {value: "NL"}}).ordered_scope

    assert_equal Customer.where(country: "NL").pluck(:id).sort, scope.pluck(:id).sort
  end

  test "a custom filter scope is applied with multiple values" do
    scope = custom_scope_table({name: {value: %w[NL DE]}}).ordered_scope

    assert_equal Customer.where(country: %w[NL DE]).pluck(:id).sort, scope.pluck(:id).sort
  end

  test "a custom filter scope is left out when the filter is not applied" do
    scope = custom_scope_table({}).ordered_scope

    assert_equal Customer.count, scope.count
    assert_no_match(/country/, scope.to_sql)
  end

  test "Filter#scope returns the proc instead of calling it" do
    f = custom_scope_table({name: {value: "NL"}}).active_filters.first

    assert_kind_of Proc, f.scope
  end

  test "the request overrides the definition's value and operator and keeps definition-only keys" do
    f = custom_scope_table({"name" => {"value" => "NL", "operator" => "is"}}).active_filters.first

    assert_equal "NL", f.value
    assert_equal :is, f.operator
    assert_kind_of Proc, f.scope
    assert_equal [:is, :isnt], f.operators.map(&:first)
    assert f.multiple?
    assert_kind_of Proc, f.config[:collection]
  end

  test "the definition's operator is used when the request has none" do
    f = custom_scope_table({name: {value: "NL"}}).active_filters.first

    assert_equal :isnt, f.operator
  end

  test "the request cannot override definition-only keys" do
    f = custom_scope_table({name: {value: "NL", scope: "bogus", having: true, multiple: false}}).active_filters.first

    assert_kind_of Proc, f.scope
    assert_not f.having?
    assert f.multiple?
  end

  test "filters on unknown columns are skipped" do
    t = CustomerFilterTable.new({filters: {nonexistent: {value: "x"}, country: {value: "NL"}}})

    assert_equal [:country], t.active_filters.map { |f| f.column.name }
  end

  test "a custom filter scope receives the operator when it accepts one" do
    assert_equal Customer.where(country: "NL").count, custom_scope_table({country: {value: "NL", operator: :is}}).ordered_scope.count
    assert_equal Customer.where.not(country: "NL").count, custom_scope_table({country: {value: "NL", operator: :isnt}}).ordered_scope.count
    assert_equal Customer.where(country: nil).count, custom_scope_table({country: {operator: :is_empty}}).ordered_scope.count
  end

  test "a custom filter scope given as a plain proc with only a value still works" do
    assert_equal Customer.where(country: "NL").count, custom_scope_table({stock_symbol: {value: "NL"}}).ordered_scope.count
  end

  test "a value the column's type can't hold matches nothing instead of raising" do
    assert_equal [], filtered_scope({number_of_employees: {value: "not a number", operator: :gt}}).to_a
    assert_equal [], filtered_scope({number_of_employees: {value: ["1", "abc"], operator: :is}}).to_a
    assert_operator filtered_scope({number_of_employees: {value: " 1 ", operator: :gteq}}).count, :>=, 0
  end
end
