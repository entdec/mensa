# frozen_string_literal: true

require "test_helper"

class FilterPillListComponentTest < ViewComponent::TestCase
  class NoFilterColumnsTable < Mensa::Base
    definition do
      model User

      column(:first_name) do
        filter false
      end

      column(:last_name) do
        filter false
      end
    end
  end

  class CollectionFilterTable < Mensa::Base
    definition do
      model User

      column(:role) do
        filter do
          collection [["Admin", "admin"], ["User", "user"], ["Guest", "guest"]]
          multiple true
        end
      end
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

  test "renders collection labels in filter pills" do
    table = CollectionFilterTable.new(filters: {role: {value: ["admin", "user"]}})

    render_inline(Mensa::FilterPillList::Component.new(table: table))

    assert_selector ".mensa-filter-pill__value", text: "Admin, User"
    assert_no_selector ".mensa-filter-pill__value", text: "admin, user"
  end
end
