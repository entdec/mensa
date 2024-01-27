require "test_helper"
require 'pry'

class TestTable < Mensa::Base
  config do
    column(:name)
    column(:state)
  end
end

class TableTest < ActiveSupport::TestCase
  test "it retuns the right column" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert :name, subject.name

    subject = t.column(:state)
    assert :state, subject.name
  end

  test "it returs the sort_direction for nil" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert_nil subject.sort_direction
  end

  test "it returs the sort_direction for asc" do
    t = TestTable.new({ order: { name: 'asc' } })
    subject = t.column(:name)
    assert_equal 'asc', subject.sort_direction
  end

  test "it returs the sort_direction for desc" do
    t = TestTable.new({ order: { name: 'desc' } })
    subject = t.column(:name)
    assert_equal 'desc', subject.sort_direction
  end

  test "it returns the right path" do
    t = Mensa::Base.new({})
    result = t.send(:order_hash, { name: 'asc' })
    assert_equal({ name: 'asc' }, result)

    t = Mensa::Base.new(result)
    result = t.send(:order_hash, { name: 'desc' })
    assert_equal({ name: 'desc' }, result)

    t = Mensa::Base.new(result)
    result = t.send(:order_hash, { name: nil })
    assert_equal({}, result)
  end
  test 'it sets order correctly' do
    t = TestTable.new(ActionController::Parameters.new({ order: { name: 'asc' } }))
    result = t.send(:order_hash, { state: 'asc' })
    assert_equal({ name: 'asc', state: 'asc' }, result)

  end
end
