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

    assert_equal({format: :long}, subject.config[:format])
    assert_equal :long, subject.format.format
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

  test "a cell renders html inside its td and csv without one" do
    t = TestTable.new({})
    user = users(:asml_user)
    cell = Mensa::Cell.new(row: Mensa::Row.new(t, user), column: t.column(:first_name))

    assert_equal "<td>#{user.first_name}</td>", cell.render(:html)
    assert_predicate cell.render(:html), :html_safe?
    assert_equal user.first_name, cell.render(:csv)
  end

  test "a cell escapes unsafe output of a custom html render inside its td" do
    t = TestTable.new({})
    t.original_view_context = ApplicationController.new.view_context
    column = Mensa::Column.new(:first_name, config: {render: {html: ->(user) { "<b>#{user.first_name}</b>" }}}, table: t)
    cell = Mensa::Cell.new(row: Mensa::Row.new(t, users(:asml_user)), column: column)

    assert_equal "<td>&lt;b&gt;#{users(:asml_user).first_name}&lt;/b&gt;</td>", cell.render(:html)
  end

  test "a cell uses the td a custom html render returns" do
    t = TestTable.new({})
    t.original_view_context = ApplicationController.new.view_context
    column = Mensa::Column.new(:first_name, config: {render: {html: ->(user) { content_tag(:td, user.first_name, class: "highlight") }}}, table: t)
    cell = Mensa::Cell.new(row: Mensa::Row.new(t, users(:asml_user)), column: column)

    assert_equal %(<td class="highlight">#{users(:asml_user).first_name}</td>), cell.render(:html)
  end

  test "a cell wraps other html from a custom html render in a td" do
    t = TestTable.new({})
    t.original_view_context = ApplicationController.new.view_context
    column = Mensa::Column.new(:first_name, config: {render: {html: ->(user) { content_tag(:span, user.first_name, class: "badge") }}}, table: t)
    cell = Mensa::Cell.new(row: Mensa::Row.new(t, users(:asml_user)), column: column)

    assert_equal %(<td><span class="badge">#{users(:asml_user).first_name}</span></td>), cell.render(:html)
  end

  test "a plain string starting with a td is escaped, not used as the td" do
    t = TestTable.new({})
    t.original_view_context = ApplicationController.new.view_context
    column = Mensa::Column.new(:first_name, config: {render: {html: ->(user) { "<td>x</td>" }}}, table: t)
    cell = Mensa::Cell.new(row: Mensa::Row.new(t, users(:asml_user)), column: column)

    assert_equal "<td>&lt;td&gt;x&lt;/td&gt;</td>", cell.render(:html)
  end
end
