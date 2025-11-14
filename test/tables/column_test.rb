require "test_helper"
require "pry"

class ColumnTest < ActiveSupport::TestCase
  test "it returns the quoted attribute" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_equal "first_name", subject.attribute
  end
  test "it return the specified attribute" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert_equal "CONCAT(first_name, last_name) AS name", subject.attribute
  end
  test "it return the specified attribute_for_condition" do
    t = TestTable.new({})
    subject = t.column(:name)
    assert_equal "CONCAT(first_name, last_name)", subject.attribute_for_condition
  end
end
