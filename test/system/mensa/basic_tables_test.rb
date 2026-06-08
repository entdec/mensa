require "application_system_test_case"

class BasicTablesTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit users_url

    assert_selector "span", text: "All users"
    assert_equal "Search and filter", find("input.mensa-table__search-bar__input")[:placeholder]
    assert_equal "All users", find("span.mensa-table__views__trigger-label").text
  end

  test "Multiselect and batch action" do
    visit users_url

    assert_equal 20, all("td input.mensa-table__select-all:not(:checked)").count
    find("th input.mensa-table__select-all").click
    assert_equal 20, all("td input.mensa-table__select-all:checked").count

    assert_text "20 selected"
    click_button "Confirm"
  end
end
