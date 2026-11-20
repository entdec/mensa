require "test_helper"

module Mensa
  module Tables
    class BatchActionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @customer = customers(:ahold)
        @user = users(:ahold_user)
      end

      test "create runs the action with the selected records" do
        post customer_users_batch_path, params: {batch_action_name: "make_guests", record_ids: [@user.id]}

        assert_response :see_other
        assert_equal "guest", @user.reload.role
      end

      test "create only uses records in the table's scope" do
        other_user = users(:asml_user)

        post customer_users_batch_path, params: {batch_action_name: "make_guests", record_ids: [other_user.id]}

        assert_response :see_other
        assert_equal "admin", other_user.reload.role
      end

      test "create with select_all uses every record matching the filters" do
        guest = @customer.users.create!(first_name: "Guest", role: "guest", email: "guest@example.com")
        admin = @customer.users.create!(first_name: "Admin", role: "admin", email: "admin@example.com")

        post customer_users_batch_path, params: {batch_action_name: "make_guests", select_all: "1", filters: {role: {operator: "is", value: "user"}}}

        assert_equal "guest", @user.reload.role
        assert_equal "guest", guest.reload.role
        assert_equal "admin", admin.reload.role
      end

      test "create with select_all and blank filters uses every record in the scope" do
        @customer.users.create!(first_name: "Admin", role: "admin", email: "admin@example.com")

        post customer_users_batch_path, params: {batch_action_name: "make_guests", select_all: "1", filters: ""}

        assert_equal ["guest"], @customer.users.reload.map(&:role).uniq
      end

      test "the records don't repeat or keep the scope's grouping" do
        post Mensa::TableParams.append_to(mensa.table_batch_actions_path("customers"), {}), params: {batch_action_name: "count", select_all: "1", filters: ""}

        assert_redirected_to "/customers"
        assert_equal "#{Customer.joins(:users).distinct.count} customers", flash[:notice]
      end

      test "create is forbidden for an action that isn't shown" do
        post customer_users_batch_path, params: {batch_action_name: "remove", record_ids: [@user.id]}

        assert_response :forbidden
        assert User.exists?(@user.id)
      end

      test "create is not found for an unknown action" do
        post customer_users_batch_path, params: {batch_action_name: "unknown", record_ids: [@user.id]}

        assert_response :not_found
      end

      test "create redirects to where the action sends it, with its notice" do
        post users_batch_path, params: {batch_action_name: "archive", record_ids: [@user.id], batch: {reason: "Left"}}

        assert_redirected_to "/users"
        assert_equal "1 users archived", flash[:notice]
        assert_equal "Left", @user.reload.archived_reason
      end

      test "create shows the dialog again with errors" do
        post users_batch_path, params: {batch_action_name: "archive", record_ids: [@user.id], batch: {reason: ""}}, headers: {"Turbo-Frame" => "mensa-batch-dialog"}

        assert_response :unprocessable_entity
        assert_select "turbo-frame#mensa-batch-dialog .mensa-batch-dialog__errors", text: /Reason can't be blank/
        assert_nil @user.reload.archived_reason
      end

      test "create outside the dialog redirects back with the errors" do
        post users_batch_path, params: {batch_action_name: "archive", record_ids: [@user.id], batch: {reason: ""}}

        assert_response :see_other
        assert_equal "Reason can't be blank", flash[:alert]
      end

      test "new renders the action's form in the dialog frame" do
        get Mensa::TableParams.append_to(mensa.new_table_batch_action_path("users"), {}), params: {batch_action_name: "archive", count: 3}

        assert_response :success
        assert_select "turbo-frame#mensa-batch-dialog form textarea[name='batch[reason]']"
        assert_select ".mensa-batch-dialog__count", text: /3/
      end

      test "new is not found for an action without a form" do
        get mensa.new_table_batch_action_path("users"), params: {batch_action_name: "confirm"}

        assert_response :not_found
      end

      private

      def customer_users_batch_path
        Mensa::TableParams.append_to(mensa.table_batch_actions_path("customer_users"), customer_id: @customer.id)
      end

      def users_batch_path
        mensa.table_batch_actions_path("users")
      end
    end
  end
end
