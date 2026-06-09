# frozen_string_literal: true

require "test_helper"

class FilterPillListComponentTest < ViewComponent::TestCase
  class NoFilterColumnsTable < Mensa::Base
    definition do
      model User

      column(:first_name)
      column(:last_name)
    end
  end

  test "renders search and filter placeholder when filterable columns exist" do
    table = TestTable.new({})

    render_inline(Mensa::FilterPillList::Component.new(table: table))

    assert_selector "input.mensa-table__search-bar__input[placeholder='Search and filter']"
    assert_selector ".mensa-table__add_filter__trigger"
  end

  test "renders search-only placeholder and hides add-filter when no filterable columns exist" do
    table = NoFilterColumnsTable.new({})

    render_inline(Mensa::FilterPillList::Component.new(table: table))

    assert_selector "input.mensa-table__search-bar__input[placeholder='Search']"
    assert_no_selector ".mensa-table__add_filter__trigger"
  end
end
