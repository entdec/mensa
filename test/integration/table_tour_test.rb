require "test_helper"

class TableTourTest < ActionDispatch::IntegrationTest
  teardown { Mensa.config.tour = true }

  test "the table starts the tour by default" do
    get users_path

    table = response.parsed_body.at_css(".mensa-table")
    assert_equal "mensa-table mensa-tour", table["data-controller"]
    assert table["data-mensa-tour-texts-value"].present?
  end

  test "config.tour = false leaves the tour out" do
    Mensa.config.tour = false
    get users_path

    table = response.parsed_body.at_css(".mensa-table")
    assert_equal "mensa-table", table["data-controller"]
    assert_nil table["data-mensa-tour-texts-value"]
  end
end
