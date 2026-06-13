require "test_helper"
require "pry"

class FormatColumnTable < Mensa::Base
  definition do
    model User

    column(:created_at)

    column(:updated_at) do
      format :iso8601 do
        time_zone { Time.zone }
      end
    end
  end
end

class ColumnTest < ActiveSupport::TestCase
  test "it returns the quoted attribute" do
    t = TestTable.new({})
    subject = t.column(:first_name)
    assert_equal "users.first_name", subject.attribute
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

  test "format defaults to db config hash" do
    t = FormatColumnTable.new({})
    subject = t.column(:created_at)

    assert_equal({format: :db}, subject.config[:format])
    assert_equal :db, subject.format.format
    assert_equal Time.zone, subject.format.time_zone
  end

  test "format stores name attribute and nested options in a single hash" do
    t = FormatColumnTable.new({})
    subject = t.column(:updated_at)
    format_config = subject.config[:format]

    assert_equal :iso8601, format_config[:format]
    assert_kind_of Proc, format_config[:time_zone]
    assert_equal({format: :iso8601, time_zone: format_config[:time_zone]}, format_config)
    assert_equal :iso8601, subject.format.format
    assert_equal Time.zone, subject.format.time_zone
  end
end
