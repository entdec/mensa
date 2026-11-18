require "test_helper"

module Mensa
  module Tables
    class RowActionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @customer = customers(:ahold)
        @user = users(:ahold_user)
      end

      test "create runs the action's process with the record" do
        post row_action_path(@customer, @user)

        assert_response :see_other
        assert_equal "admin", @user.reload.role
      end

      test "create only finds records in the table's scope" do
        other_user = users(:sap_user)

        post row_action_path(@customer, other_user)

        assert_response :not_found
        assert_equal "guest", other_user.reload.role
      end

      test "create doesn't run an action that isn't shown for the record" do
        @user.update!(role: "admin")

        post row_action_path(@customer, @user)

        assert_response :not_found
      end

      test "create is not found for an unknown action" do
        post Mensa::TableParams.append_to(mensa.table_row_action_path("customer_users", "unknown", @user.id), customer_id: @customer.id)

        assert_response :not_found
      end

      test "the row action renders as a Turbo POST link" do
        table = Mensa.for_name("customer_users", params: {customer_id: @customer.id})
        table.original_view_context = ApplicationController.new.view_context
        row = Mensa::Row.new(table, @user)
        action = table.actions.find { |a| a.name == :promote }

        html = ApplicationController.render(Mensa::RowAction::Component.new(table: table, row: row, action: action), layout: false)

        assert_includes html, %(data-turbo-method="post")
        assert_includes html, mensa.table_row_action_path("customer_users", "promote", @user.id)
      end

      private

      def row_action_path(customer, user)
        Mensa::TableParams.append_to(mensa.table_row_action_path("customer_users", "promote", user.id), customer_id: customer.id)
      end
    end
  end
end
