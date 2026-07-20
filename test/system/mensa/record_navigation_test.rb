require "application_system_test_case"

class RecordNavigationTest < ApplicationSystemTestCase
  test "users edit view shows next and previous links with table context" do
    visit users_url
    assert_selector "tbody tr", wait: 5

    find("thead a", text: "Email").click
    assert_selector "tbody tr", wait: 5

    second_row = first("tbody tr:nth-child(2)")
    href = second_row["href"]
    assert href.present?, "Row should carry an href"

    visit href

    assert_selector "a", text: "Previous user"
    assert_selector "a", text: "Next user"

    previous_href = find("a", text: "Previous user")[:href]
    next_href = find("a", text: "Next user")[:href]

    previous_query = Rack::Utils.parse_nested_query(URI.parse(previous_href).query)
    next_query = Rack::Utils.parse_nested_query(URI.parse(next_href).query)

    assert_equal "asc", previous_query.dig("order", "email")
    assert_equal "asc", next_query.dig("order", "email")
  end

  test "customers edit view shows next and previous links with table context" do
    visit customers_url
    assert_selector "tbody tr", wait: 5

    find("thead a", text: "Name").click
    assert_selector "tbody tr", wait: 5

    second_row = first("tbody tr:nth-child(2)")
    href = second_row["href"]
    assert href.present?, "Row should carry an href"

    visit href

    assert_selector "a", text: "Previous customer"
    assert_selector "a", text: "Next customer"

    previous_href = find("a", text: "Previous customer")[:href]
    next_href = find("a", text: "Next customer")[:href]

    previous_query = Rack::Utils.parse_nested_query(URI.parse(previous_href).query)
    next_query = Rack::Utils.parse_nested_query(URI.parse(next_href).query)

    assert_equal "asc", previous_query.dig("order", "name")
    assert_equal "asc", next_query.dig("order", "name")
  end
end
