require "test_helper"

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

  test "the badge shows the number of completed downloads" do
    Mensa::Export.create!(table_name: "users", user: User.first, status: "completed", filename: "users_export.csv")

    get root_path

    assert_response :success
    assert_select "##{Mensa::Export.badge_dom_id("users", User.first)}", text: "1"
  end
end
