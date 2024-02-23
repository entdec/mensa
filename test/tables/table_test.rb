require "test_helper"
require 'pry'

class TestTable < Mensa::Base
  definition do
    model User
    
    column(:first_name)
    column(:last_name)
    column(:name) do
      attribute 'CONCAT(first_name, last_name)'
    end

    link { |test| root_path }
  end
end

class TableTest < ActiveSupport::TestCase
  test "it retuns the right column" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_equal :first_name, subject.name

    subject = t.column(:last_name)
    assert_equal :last_name, subject.name
  end

  test "it returs the sort_direction for nil" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_nil subject.sort_direction
  end

  test "it returs the sort_direction for asc" do
    t = TestTable.new({ order: { first_name: :asc } })
    subject = t.column(:first_name)
    assert_equal :asc, subject.sort_direction
  end

  test "it returs the sort_direction for desc" do
    t = TestTable.new({ order: { first_name: :desc } })
    subject = t.column(:first_name)
    assert_equal :desc, subject.sort_direction
  end

  test "it returns the right path" do
    t = Mensa::Base.new({})
    result = t.send(:order_hash, { first_name: :asc })
    assert_equal({ first_name: :asc }, result)

    t = Mensa::Base.new(result)
    result = t.send(:order_hash, { first_name: :desc })
    assert_equal({ first_name: :desc }, result)

    t = Mensa::Base.new(result)
    result = t.send(:order_hash, { first_name: nil })
    assert_equal({}, result)
  end

  test 'it sets order correctly' do
    t = TestTable.new(ActionController::Parameters.new(order: { first_name: :asc }).permit!.to_h.deep_symbolize_keys)
    result = t.send(:order_hash, { last_name: :asc })
    assert_equal({ first_name: :asc, last_name: :asc }, result)
  end

  test 'it returns row link' do
    t = TestTable.new({})
    result = t.link
    assert_equal Proc, result.class
    assert_equal 1, result.arity
  end
end
