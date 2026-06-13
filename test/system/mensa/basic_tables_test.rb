require "application_system_test_case"

class BasicTablesTest < ApplicationSystemTestCase
  # Row-action buttons are rendered before the data cells (row_actions_position = :front).
  # Column layout: td1=checkbox, td2=actions, td3=first_name, td4=last_name,
  #                td5=email, td6=role, td7=customer_name
  FIRST_NAME_COL = "td:nth-child(3)"

  test "visiting the index" do
    visit users_url

    assert_selector "span", text: "All users"
    assert_equal "Search and filter", find("input.mensa-table__search-bar__input")[:placeholder]
    assert_equal "All users", find("span.mensa-table__views__trigger-label").text
  end

  test "tables without filterable columns show a search-only input" do
    visit search_only_users_url

    assert_text "Search only users"
    assert_equal "Search", find("input.mensa-table__search-bar__input")[:placeholder]
    assert_no_selector ".mensa-table__add_filter__trigger"
  end

  test "typing in a search-only table does not open any filter popover" do
    visit search_only_users_url

    input = find("input.mensa-table__search-bar__input")
    input.click
    input.set("Oliver")

    assert_equal "Oliver", input.value
    assert_no_selector ".mensa-table__add_filter"
    assert_no_selector ".mensa-table__add_filter__popover_container"
  end

  test "headerless tables render rows without a table header" do
    visit headerless_users_url

    assert_text "Headerless users"
    assert_selector "tbody tr", wait: 15
    assert_no_selector "thead"
    assert_no_selector "span.mensa-table__views__trigger-label"
  end

  test "clicking a row navigates to the row's linked path" do
    visit users_url
    assert_selector "tbody tr", wait: 15

    first_row = first("tbody tr")
    expected_path = first_row["href"]
    assert expected_path.present?, "Row should carry an href"
    first("tbody tr #{FIRST_NAME_COL}").click

    assert_current_path expected_path
  end

  test "every row links to a distinct edit path" do
    visit users_url
    assert_selector "tbody tr", wait: 15

    hrefs = all("tbody tr").map { |tr| tr["href"] }
    assert hrefs.all?(&:present?), "Every row should have an href"
    assert_equal hrefs.length, hrefs.uniq.length, "Each row should link to a different path"
  end

  test "clicking a sortable column header sorts rows ascending" do
    visit users_url
    assert_selector "tbody tr", wait: 15

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 15

    first_names = all("tbody tr #{FIRST_NAME_COL}").map(&:text)
    assert_equal first_names, User.order(:first_name).limit(first_names.length).pluck(:first_name),
      "First names should match the database ascending order after sort"
  end

  test "clicking the same sortable column header a second time sorts descending" do
    visit users_url
    assert_selector "tbody tr", wait: 15

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 15
    first_asc = first("tbody tr #{FIRST_NAME_COL}").text

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 15

    first_names_desc = all("tbody tr #{FIRST_NAME_COL}").map(&:text)
    assert_equal first_names_desc, User.order(first_name: :desc).limit(first_names_desc.length).pluck(:first_name),
      "First names should match the database descending order after second click"

    first_desc = first_names_desc.first
    assert_not_equal first_asc, first_desc,
      "Ascending and descending first rows should differ"
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
