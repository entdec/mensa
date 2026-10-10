require "test_helper"

module Mensa
  class TablesControllerTest < ActionDispatch::IntegrationTest
    test "renders group headers with counts" do
      get mensa.table_path("customers", group_by: "country")

      assert_response :success
      # The first page has 20 rows: CH (3), DE (8), DK (1), ES (1) and FR (7)
      assert_select "tr.mensa-table__group-header", 5
      assert_select "tr.mensa-table__group-header .mensa-table__group-header__value", text: "CH"
      assert_select "tr.mensa-table__group-header .mensa-table__group-header__count", text: "3"
      assert_select "table[data-controller='mensa-groups']"
      assert_select "tr[data-mensa-groups-target='row'][data-group-key]"
    end

    test "renders the aggregates in their column" do
      Customer.update_all(market_cap: 1000)

      get mensa.table_path("customers", group_by: "country", aggregates: {market_cap: "sum"})

      assert_response :success
      assert_select "tr.mensa-table__group-header td .mensa-table__group-header__aggregate", text: /Sum\s+3,000/
      assert_select "[data-mensa-table-target='view'][data-group-by='country'][data-aggregates='{\"market_cap\":\"sum\"}']"
    end

    test "is not grouped without group_by" do
      get mensa.table_path("customers")

      assert_response :success
      assert_select "tr.mensa-table__group-header", 0
      assert_select "[data-mensa-table-target='view'][data-group-by='']"
    end

    test "blank group_by and aggregates override the view's" do
      view = Mensa::TableView.create!(table_name: "customers", name: "By country", user: User.first,
        config: {group_by: "country", aggregates: {market_cap: "sum"}})

      get mensa.table_path("customers", table_view_id: view.id)
      assert_select "tr.mensa-table__group-header"

      get mensa.table_path("customers", table_view_id: view.id, group_by: "country", aggregates: "")
      assert_select "tr.mensa-table__group-header"
      assert_select ".mensa-table__group-header__aggregate", 0

      get mensa.table_path("customers", table_view_id: view.id, group_by: "")
      assert_select "tr.mensa-table__group-header", 0
    end

    test "user views store the grouping" do
      post mensa.table_views_path("customers"),
        params: {name: "By industry", group_by: "industry", aggregates: {market_cap: "max"}, turbo_frame_id: "customers"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"},
        as: :json

      assert_response :success
      view = Mensa::TableView.find_by!(table_name: "customers", name: "By industry")
      assert_equal "industry", view.config["group_by"]
      assert_equal({"market_cap" => "max"}, view.config["aggregates"])
    end
  end
end
