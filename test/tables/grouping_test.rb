require "test_helper"

class GroupedCustomerTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:country) do
      groupable true
    end
    column(:industry) do
      groupable true
    end
    column(:isin)
    column(:number_of_employees) do
      aggregates :sum, :min, :max, :count
    end
  end
end

class DefaultGroupedCustomerTable < Mensa::Base
  definition do
    model Customer

    column(:name)
    column(:country) do
      groupable true
    end
    column(:number_of_employees) do
      aggregates :sum
    end

    group_by :country
    aggregates number_of_employees: :sum

    view :ungrouped do
      name "Ungrouped"
      group_by ""
    end
  end
end

class GroupingTest < ActiveSupport::TestCase
  def table(config = {})
    t = GroupedCustomerTable.new(config)
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    t
  end

  test "tables are not grouped by default" do
    t = table

    assert_not t.grouped?
    assert_empty t.groups
    assert_no_match(/mensa_group_value/, t.selected_scope.to_sql)
  end

  test "group_by sorts by the group column first" do
    t = table(group_by: :country, order: {name: :asc})

    assert t.grouped?
    assert_equal Customer.order(:country, :name).pluck(:id), t.ordered_scope.pluck(:id)
  end

  test "the group direction follows the order of the group column" do
    t = table(group_by: :country, order: {country: :desc, name: :asc})

    assert_equal Customer.order(country: :desc, name: :asc).pluck(:id), t.ordered_scope.pluck(:id)
  end

  test "groups count all filtered rows, not just the current page" do
    t = table(group_by: :country)

    assert_equal Customer.group(:country).count, t.groups.transform_values(&:count)
    assert_operator t.rows.size, :<, Customer.count
  end

  test "groups respect filters" do
    t = table(group_by: :country, filters: {country: {value: %w[NL DE]}})

    assert_equal({"DE" => 8, "NL" => 4}, t.groups.transform_values(&:count))
  end

  test "rows carry their group value" do
    t = table(group_by: :country)

    assert_equal Customer.order(:country).limit(t.rows.size).pluck(:country), t.rows.map(&:group_value)
    assert_equal 8, t.group_for(t.rows.find { |row| row.group_value == "DE" }).count
  end

  test "aggregates are calculated per group" do
    Customer.find_each.with_index { |customer, index| customer.update_columns(number_of_employees: index + 1) }
    Customer.find_by!(name: "ASML").update_columns(number_of_employees: nil)

    t = table(group_by: :country, aggregates: {number_of_employees: :sum})
    assert_equal Customer.group(:country).sum(:number_of_employees), t.groups.transform_values { |g| g.aggregates[:number_of_employees] }

    t = table(group_by: :country, aggregates: {number_of_employees: :max})
    assert_equal Customer.group(:country).maximum(:number_of_employees), t.groups.transform_values { |g| g.aggregates[:number_of_employees] }

    t = table(group_by: :country, aggregates: {number_of_employees: :min})
    assert_equal Customer.group(:country).minimum(:number_of_employees), t.groups.transform_values { |g| g.aggregates[:number_of_employees] }

    t = table(group_by: :country, aggregates: {number_of_employees: "count"})
    assert_equal 3, t.groups["NL"].aggregates[:number_of_employees], "count skips empty values"
  end

  test "aggregates are formatted with delimiters" do
    Customer.update_all(number_of_employees: 1_000_000)
    t = table(group_by: :country, aggregates: {number_of_employees: :sum})

    assert_equal "4,000,000", t.groups["NL"].aggregate(t.column(:number_of_employees))
    assert_equal "Sum", t.groups["NL"].aggregate_label(t.column(:number_of_employees))
    assert_nil t.groups["NL"].aggregate(t.column(:name))
  end

  test "rows without a value form their own group" do
    Customer.where(country: "NL").update_all(industry: "Tech")
    t = table(group_by: :industry)

    assert_equal({"Tech" => 4, nil => Customer.count - 4}, t.groups.transform_values(&:count))
    assert_equal "No Industry", t.groups[nil].title
    assert_equal "Tech", t.groups["Tech"].title
    assert_equal "none", t.groups[nil].key
  end

  test "columns that are not groupable are ignored" do
    assert_not table(group_by: :isin).grouped?
    assert_not table(group_by: :unknown).grouped?
    assert_not table(group_by: "").grouped?
  end

  test "aggregates that are not allowed are ignored" do
    t = table(group_by: :country, aggregates: {number_of_employees: :avg, name: :max, unknown: :sum, isin: :count})

    assert_empty t.current_aggregates
  end

  test "grouping works on scopes with their own group by and aggregate attributes" do
    asml = customers(:asml)
    User.create!(email: "extra-1@mensa.test", first_name: "A", last_name: "A", role: "user", customer: asml)

    t = CustomersTable.new({group_by: :country, aggregates: {users_count: :sum}})
    t.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))

    assert_equal 4, t.groups["NL"].count
    assert_equal 5, t.groups["NL"].aggregates[:users_count]
  end

  test "the path keeps the grouping, blank overrides a default" do
    assert_equal "country", table(group_by: :country).send(:group_by_param)
    assert_nil table.send(:group_by_param)
    assert_equal({number_of_employees: :sum}, table(group_by: :country, aggregates: {number_of_employees: :sum}).send(:aggregates_param))
    assert_equal "", table(group_by: "", aggregates: {}).send(:group_by_param)
    assert_equal "", table(group_by: "", aggregates: {}).send(:aggregates_param)
  end

  test "the navigation context keeps the grouping" do
    assert_equal :country, table(group_by: :country).navigation_context[:group_by]
    assert_not table.navigation_context.key?(:group_by)
  end

  test "group_by and aggregates can be set in the definition" do
    t = DefaultGroupedCustomerTable.new({})

    assert t.grouped?
    assert_equal({number_of_employees: :sum}, t.current_aggregates)
  end

  test "views can override the grouping" do
    view = DefaultGroupedCustomerTable.new({}).system_views.find { |v| v.id == :ungrouped }

    assert_not DefaultGroupedCustomerTable.new(view.config).grouped?
  end
end
