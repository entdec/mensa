require "test_helper"
require "pry"

class InitializeExplodingScopeTable < Mensa::Base
  model User

  column(:first_name)

  scope do
    raise "scope should not run during initialize"
  end
end

# A read-only model backed by a subquery, without an id column.
class RoleCount < ApplicationRecord
  self.table_name = "role_counts"

  def self.load_schema!
    @columns_hash = {}
  end

  def self.column_names
    %w[role total]
  end

  def self.subquery
    from(User.group(:role).select("role, COUNT(*) AS total"), :role_counts)
  end
end

class RoleCountsTable < Mensa::Base
  model RoleCount

  column(:role)
  column(:total)

  scope { RoleCount.subquery }
end

class UnnamedDefaultViewTable < Mensa::Base
  model User

  column(:first_name)
  column(:role)

  view :default do
    filter :role do
      value "user"
    end
  end
end

class TableTest < ActiveSupport::TestCase
  test "it returns the right column" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_equal :first_name, subject.name

    subject = t.column(:last_name)
    assert_equal :last_name, subject.name
  end

  test "it returns the sort_direction for nil" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_nil subject.sort_direction
  end

  test "it returns the sort_direction for asc" do
    t = TestTable.new({order: {first_name: :asc}})
    subject = t.column(:first_name)
    assert_equal :asc, subject.sort_direction
  end

  test "it returns the sort_direction for desc" do
    t = TestTable.new({order: {first_name: :desc}})
    subject = t.column(:first_name)
    assert_equal :desc, subject.sort_direction
  end

  test "it returns the right direction after consecutive calls" do
    t = TestTable.new({})
    result = t.send(:order_hash, {first_name: :asc})
    assert_equal({first_name: :asc}, result)

    t = TestTable.new(result)
    result = t.send(:order_hash, {first_name: :desc})
    assert_equal({first_name: :desc}, result)

    t = TestTable.new(result)
    result = t.send(:order_hash, {first_name: nil})
    assert_equal({first_name: ""}, result)
  end

  test "it sets order correctly" do
    t = TestTable.new(ActionController::Parameters.new(order: {first_name: :asc}).permit!.to_h.deep_symbolize_keys)
    result = t.send(:order_hash, {last_name: :asc})
    assert_equal({first_name: :asc, last_name: :asc}, result)
  end

  test "it returns row link" do
    t = TestTable.new({})
    result = t.link
    assert_equal Proc, result.class
    assert_equal 1, result.arity
  end

  test "it automatically adds internal fk columns for joined associations" do
    t = UsersTable.new({})

    assert t.column(:customer_id).internal?
    assert_includes t.display_columns.map(&:name), :customer_name
    assert_not_includes t.display_columns.map(&:name), :customer_id
  end

  test "internal helper disables filtering on the generated column" do
    t = TestTable.new({})
    column = t.column(:customer_id)

    assert_equal true, column.internal?
    assert_equal false, column.filter?
    assert_nil column.filter
  end

  test "next_record and previous_record follow table ordering" do
    t = TestTable.new({order: {email: :asc}})
    ordered_ids = t.ordered_scope.pluck(:id)
    middle_record = User.find(ordered_ids[1])

    assert_equal ordered_ids[2], t.next_record(middle_record)&.id
    assert_equal ordered_ids[0], t.previous_record(middle_record)&.id
  end

  test "next_record and previous_record respect active filters" do
    t = CustomerTable.new({order: {name: :asc}, filters: {country: {value: "NL"}}})
    ordered_ids = t.ordered_scope.pluck(:id)
    middle_record = Customer.find(ordered_ids[1])

    assert_equal ordered_ids[2], t.next_record(middle_record)&.id
    assert_equal ordered_ids[0], t.previous_record(middle_record)&.id

    outside_filtered_scope = customers(:sap)
    assert_nil t.next_record(outside_filtered_scope)
    assert_nil t.previous_record(outside_filtered_scope)
  end

  test "next_record and previous_record ignore pagination" do
    unpaged_table = TestTable.new({order: {email: :asc}})
    paged_table = TestTable.new({order: {email: :asc}, page: 2})
    target_record = User.find(unpaged_table.ordered_scope.pluck(:id)[5])

    assert_equal unpaged_table.next_record(target_record)&.id, paged_table.next_record(target_record)&.id
    assert_equal unpaged_table.previous_record(target_record)&.id, paged_table.previous_record(target_record)&.id
  end

  test "next_record and previous_record return nil at boundaries" do
    t = TestTable.new({order: {email: :asc}})
    ordered_ids = t.ordered_scope.pluck(:id)
    first_record = User.find(ordered_ids.first)
    last_record = User.find(ordered_ids.last)

    assert_nil t.previous_record(first_record)
    assert_nil t.next_record(last_record)
  end

  test "unknown column names in browser state are ignored" do
    t = TestTable.new({
      column_order: %w[gone last_name first_name],
      hidden_columns: %w[gone role],
      order: {gone: :asc, last_name: :desc},
      filters: {gone: {value: "x"}}
    })

    assert_equal %i[last_name first_name], t.display_columns.map(&:name)
    assert_empty t.active_filters
    assert_nothing_raised { t.ordered_scope.to_a }
    assert_no_match(/gone/, t.ordered_scope.to_sql)
  end

  test "a column_order with only unknown names falls back to all columns" do
    t = TestTable.new({column_order: %w[gone]})

    assert_equal %i[first_name last_name name role], t.display_columns.map(&:name)
  end

  test "order on a model attribute that isn't a column is kept" do
    t = TestTable.new({order: {email: :asc}})

    assert_match(/email asc/i, t.ordered_scope.to_sql)
  end

  test "selected_scope only selects id when the relation has that column" do
    assert_match(/"id"|\bid\b/, TestTable.new({}).selected_scope.to_sql)

    t = RoleCountsTable.new({})
    assert_no_match(/\bid\b/, t.selected_scope.to_sql)
    assert_equal User.distinct.count(:role), t.selected_scope.to_a.size
  end

  test "path_with_params and storage_key include the table's params" do
    customer = customers(:asml)
    t = Mensa.for_name("customer_users", params: {customer_id: customer.id})

    assert_equal "/x?params%5Bcustomer_id%5D=#{customer.id}", t.path_with_params("/x")
    assert_match(/\Acustomer_users:[0-9a-f]{12}\z/, t.storage_key)
    assert_equal "/x", TestTable.new({}).path_with_params("/x")
  end

  test "a redefined default view without a name keeps the translated name" do
    view = UnnamedDefaultViewTable.new({}).default_system_view

    assert_equal I18n.t("mensa.views.default"), view.name
    assert_equal "user", view.config.dig(:filters, :role, :value)
  end

  test "a redefined default view can set its own name" do
    assert_equal "All users", Mensa.for_name("users").default_system_view.name
  end

  test "ordering on a column with a custom attribute expression" do
    t = TestTable.new({order: {name: :desc}})
    expected = User.order(Arel.sql("CONCAT(first_name, last_name) DESC")).pluck(:id)

    assert_nothing_raised { t.ordered_scope.to_a }
    assert_equal expected, t.ordered_scope.pluck(:id)
  end

  test "order direction is case insensitive" do
    t = TestTable.new({order: {first_name: "DESC"}})

    assert_match(/"first_name" desc NULLS LAST/, t.ordered_scope.to_sql[/ORDER BY.*/])
  end

  test "unknown order directions are ignored" do
    t = TestTable.new({order: {first_name: "asc; DROP TABLE users", last_name: :asc}})
    sql = t.ordered_scope.to_sql

    assert_no_match(/DROP/, sql)
    assert_equal 'ORDER BY "users"."last_name" asc NULLS LAST', sql[/ORDER BY.*/]
  end
end
