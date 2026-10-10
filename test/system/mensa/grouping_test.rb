require "application_system_test_case"

class GroupingTest < ApplicationSystemTestCase
  setup do
    # Visit the page first so we can clear this origin's localStorage,
    # preventing state from leaking between tests.
    visit customers_url
    execute_script("localStorage.clear()")
  end

  def group_by(label)
    find(".mensa-table__control_bar__button[data-mensa-group-by-target='button']").click
    find(".mensa-table__group_by__option", text: label).click
  end

  test "grouping by a column shows group headers with counts" do
    visit customers_url
    group_by "Country"

    assert_selector "tr.mensa-table__group-header", minimum: 1
    header = first("tr.mensa-table__group-header")
    assert_equal "CH", header.find(".mensa-table__group-header__value").text
    assert_equal "3", header.find(".mensa-table__group-header__count").text
  end

  test "the grouping is remembered and can be turned off" do
    visit customers_url
    group_by "Country"
    assert_selector "tr.mensa-table__group-header", minimum: 1

    visit customers_url
    assert_selector "tr.mensa-table__group-header", minimum: 1

    group_by "No grouping"
    assert_no_selector "tr.mensa-table__group-header"
  end

  test "collapsing a group hides its rows and is remembered" do
    visit customers_url
    group_by "Country"

    header = first("tr.mensa-table__group-header")
    key = header["data-group-key"]
    header.click

    assert_equal "false", header["aria-expanded"]
    assert_no_selector "tr[data-mensa-groups-target='row'][data-group-key='#{key}']", visible: true

    visit customers_url
    assert_selector "tr.mensa-table__group-header[data-group-key='#{key}'][aria-expanded='false']"

    find("tr.mensa-table__group-header[data-group-key='#{key}']").click
    assert_selector "tr[data-mensa-groups-target='row'][data-group-key='#{key}']", visible: true, count: 3
  end

  test "choosing an aggregate shows it in the group headers" do
    Customer.update_all(market_cap: 1000)

    visit customers_url
    group_by "Country"
    find("select[data-column-name='market_cap']").select("Sum")

    assert_selector "tr.mensa-table__group-header .mensa-table__group-header__aggregate", text: /Sum\s*3,000/
  end
end
