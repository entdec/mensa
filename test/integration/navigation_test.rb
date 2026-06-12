require "test_helper"
require "uri"

class NavigationTest < ActionDispatch::IntegrationTest
  test "the table page renders the export button, badge and dialog" do
    get root_path

    assert_response :success

    # Export button and its (hidden) download-count badge.
    assert_select "[data-action='mensa-table#export']"
    assert_select "##{Mensa::Export.badge_dom_id("users", User.first)}"

    # Export dialog with the downloads list and the new-export form.
    assert_select "dialog.mensa-table__export-dialog"
    assert_select "##{Mensa::Export.list_dom_id("users", User.first)}"
    assert_select "input[name=export_format]"
    assert_select "input[name=scope]"

    # Turbo stream subscription so finished exports update the badge live.
    assert_select "turbo-cable-stream-source"
  end

  test "the badge shows the number of downloadable exports" do
    export = Mensa::Export.create!(table_name: "users", user: User.first, status: "completed", filename: "users_export.csv")
    export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "users_export.csv", content_type: "text/csv")

    get root_path

    assert_response :success
    assert_select "##{Mensa::Export.badge_dom_id("users", User.first)}", text: "1"
  end

  test "table helper preserves nested params in the turbo frame url and frame request" do
    get scoped_users_path

    assert_response :success

    table_el = Nokogiri::HTML(response.body).at_css(".mensa-table")
    assert table_el, "Expected the scoped users page to render a mensa table"

    table_url = table_el["data-mensa-table-table-url-value"]
    assert table_url.present?, "Expected the rendered table to expose a turbo frame URL"

    uri = URI.parse(table_url)
    query = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "ASML", query.dig("params", "customer_name")

    request_path = uri.query.present? ? "#{uri.path}?#{uri.query}" : uri.path
    get request_path

    assert_response :success
    assert_includes response.body, users(:asml_user).first_name
    assert_not_includes response.body, users(:sap_user).first_name
  end
end
