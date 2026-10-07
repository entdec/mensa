require "test_helper"

module Mensa
  module Tables
    class ViewsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @customer = customers(:asml)
      end

      test "create re-renders a table that needs params with the params from the views URL" do
        post Mensa::TableParams.append_to(mensa.table_views_path("customer_users"), customer_id: @customer.id),
          params: {name: "Admins", filters: {role: {value: "admin"}}, turbo_frame_id: "customer-users"},
          headers: {"Accept" => "text/vnd.turbo-stream.html"},
          as: :json

        assert_response :success
        view = Mensa::TableView.find_by!(table_name: "customer_users", name: "Admins")
        assert_not view.config.key?("params"), "params identify the table, they are not part of the view"
      end
    end
  end
end
