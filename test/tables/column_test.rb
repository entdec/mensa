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

class ColumnTest < ActiveSupport::TestCase
  test "it returns the quoted atribute" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_equal 'first_name', subject.attribute
  end
  test "it return the specified attribute" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert_equal 'CONCAT(first_name, last_name) AS name', subject.attribute
  end
  test "it return the specified attribute_for_condition" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert_equal 'CONCAT(first_name, last_name)', subject.attribute_for_condition
  end
end