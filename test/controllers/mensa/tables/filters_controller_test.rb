require "test_helper"

module Mensa
  module Tables
    class FiltersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @customer = customers(:asml)
      end

      # The add-filter popover requests the filter from the table URL, which
      # carries the table's params as params[...] (see Mensa::Base#path).
      test "show builds the table with the table's params" do
        get mensa.table_filter_path("customer_users", "role", params: {target: "popover"}) + "&" + {params: {customer_id: @customer.id}}.to_query,
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_match "popover", response.body
        assert_match "admin", response.body
      end

      test "show fails for a table that needs params when they are missing" do
        assert_raises(KeyError) do
          get mensa.table_filter_path("customer_users", "role", target: "popover"),
            headers: {"Accept" => "text/vnd.turbo-stream.html"}
        end
      end
    end
  end
end
