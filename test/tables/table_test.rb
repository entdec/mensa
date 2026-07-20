require "test_helper"
require "pry"

class InitializeExplodingScopeTable < Mensa::Base
  model User

  column(:first_name)

  scope do
    raise "scope should not run during initialize"
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
end
