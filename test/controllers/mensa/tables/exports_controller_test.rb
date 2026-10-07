require "test_helper"

module Mensa
  module Tables
    class ExportsControllerTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper

      setup do
        @user = User.first
      end

      test "create persists an export and enqueues the job with the complete table state" do
        view = Mensa::TableView.create!(
          table_name: "users",
          name: "Admins",
          user: @user,
          config: {}
        )

        assert_difference -> { Mensa::Export.count }, 1 do
          assert_enqueued_with(job: Mensa::ExportJob) do
            post mensa.table_exports_path("users"),
              params: {
                export_format: "plain_csv",
                scope: "all",
                table_view_id: view.id,
                page: "2",
                query: "smith",
                filters: {role: {value: "admin", operator: "is"}},
                order: {email: "desc"},
                column_order: ["email", "first_name", "role"],
                hidden_columns: ["role"]
              },
              as: :json
          end
        end

        assert_response :created

        export = Mensa::Export.order(:created_at).last
        assert_equal "users", export.table_name
        assert_equal "plain_csv", export.format
        assert_equal "all", export.scope
        assert_equal view.id, export.table_view_id
        assert_equal @user, export.user
        assert_equal "2", export.config["page"]
        assert_equal "smith", export.config["query"]
        assert_equal view.id, export.config["table_view_id"]
        assert_equal "admin", export.config.dig("filters", "role", "value")
        assert_equal "is", export.config.dig("filters", "role", "operator")
        assert_equal "desc", export.config.dig("order", "email")
        assert_equal ["email", "first_name", "role"], export.config["column_order"]
        assert_equal ["role"], export.config["hidden_columns"]
        assert_equal "", export.repeat
      end

      test "create persists the selected repeat schedule" do
        post mensa.table_exports_path("users"),
          params: {export_format: "plain_csv", scope: "all", repeat: "weekly"},
          as: :json

        assert_response :created
        assert_equal "weekly", Mensa::Export.order(:created_at).last.repeat
      end

      test "create falls back to safe defaults for unknown format, scope, and repeat" do
        post mensa.table_exports_path("users"),
          params: {export_format: "bogus", scope: "bogus", repeat: "bogus"},
          as: :json

        export = Mensa::Export.order(:created_at).last
        assert_equal "csv_excel", export.format
        assert_equal "all", export.scope
        assert_equal "", export.repeat
      end

      test "create responds with a turbo stream updating the list and badge" do
        post mensa.table_exports_path("users"),
          params: {export_format: "plain_csv", scope: "all"},
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_match Mensa::Export.list_dom_id("users", @user), response.body
        assert_match Mensa::Export.badge_dom_id("users", @user), response.body
      end

      test "index renders the downloads list" do
        Mensa::Export.create!(table_name: "users", user: @user, status: "completed", filename: "users_export.csv")

        get mensa.table_exports_path("users"),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_match Mensa::Export.list_dom_id("users", @user), response.body
        assert_match "users_export.csv", response.body
        assert_match "fa-trash", response.body
      end

      test "destroy removes an export and updates the list and badge" do
        export = Mensa::Export.create!(table_name: "users", user: @user, status: "completed", filename: "users_export.csv")
        export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "users_export.csv", content_type: "text/csv")
        blob_id = export.asset.blob.id

        delete mensa.table_export_path("users", export),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_match Mensa::Export.list_dom_id("users", @user), response.body
        assert_match Mensa::Export.badge_dom_id("users", @user), response.body
        assert_not Mensa::Export.exists?(export.id)

        perform_enqueued_jobs
        assert_not ActiveStorage::Blob.exists?(blob_id)
      end

      test "destroy does not expose another user's export" do
        other = User.where.not(id: @user.id).first
        export = Mensa::Export.create!(table_name: "users", user: other, status: "completed")

        delete mensa.table_export_path("users", export),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :not_found
        assert Mensa::Export.exists?(export.id)
      end

      test "download streams the asset, then deletes the one-off export and purges the asset" do
        export = Mensa::Export.create!(table_name: "users", user: @user, status: "completed", filename: "users_export.csv")
        export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "users_export.csv", content_type: "text/csv")
        blob_id = export.asset.blob.id

        perform_enqueued_jobs do
          get mensa.download_table_export_path("users", export)
        end

        assert_response :success
        assert_equal "a,b\n1,2\n", response.body
        assert_equal "text/csv", response.media_type
        assert_match(/attachment/, response.headers["Content-Disposition"])

        assert_not Mensa::Export.exists?(export.id)
        assert_not ActiveStorage::Blob.exists?(blob_id)
      end

      test "download keeps repeating exports after streaming the asset" do
        export = Mensa::Export.create!(table_name: "users", user: @user, status: "completed", filename: "users_export.csv", repeat: "weekly")
        export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "users_export.csv", content_type: "text/csv")
        blob_id = export.asset.blob.id

        get mensa.download_table_export_path("users", export)

        assert_response :success
        assert_equal "a,b\n1,2\n", response.body
        assert_equal "text/csv", response.media_type
        assert_match(/attachment/, response.headers["Content-Disposition"])

        assert Mensa::Export.exists?(export.id)
        assert ActiveStorage::Blob.exists?(blob_id)
      end

      test "download returns not found for an export that is not downloadable" do
        export = Mensa::Export.create!(table_name: "users", user: @user, status: "pending")

        get mensa.download_table_export_path("users", export)

        assert_response :not_found
        assert Mensa::Export.exists?(export.id)
      end

      test "download does not expose another user's export" do
        other = User.where.not(id: @user.id).first
        export = Mensa::Export.create!(table_name: "users", user: other, status: "completed")
        export.asset.attach(io: StringIO.new("x\n"), filename: "x.csv", content_type: "text/csv")

        get mensa.download_table_export_path("users", export)

        assert_response :not_found
        assert Mensa::Export.exists?(export.id)
      end
      test "create saves the table's params sent in the exports URL" do
        customer = customers(:asml)

        assert_enqueued_with(job: Mensa::ExportJob) do
          post exports_path_with_params("customer_users", customer_id: customer.id),
            params: {export_format: "plain_csv", scope: "all", filters: {role: {value: "user"}}},
            as: :json
        end

        assert_response :created
        export = Mensa::Export.order(:created_at).last
        assert_equal "customer_users", export.table_name
        assert_equal({"customer_id" => customer.id}, export.config["params"])
        assert_equal({"customer_id" => customer.id}, export.table_params)
        assert_equal "user", export.config.dig("filters", "role", "value")
      end

      test "create saves params sent in the request body, normalized to strings" do
        post mensa.table_exports_path("users"),
          params: {export_format: "plain_csv", scope: "all", params: {limit: 5, tags: ["a", "b"]}},
          as: :json

        assert_response :created
        assert_equal({"limit" => "5", "tags" => ["a", "b"]}, Mensa::Export.order(:created_at).last.config["params"])
      end

      test "create does not store params when the table has none" do
        post mensa.table_exports_path("users"), params: {export_format: "plain_csv"}, as: :json

        assert_not Mensa::Export.order(:created_at).last.config.key?("params")
      end

      test "index only lists the exports of the table built with the same params" do
        asml = customers(:asml)
        sap = customers(:sap)
        Mensa::Export.create!(table_name: "customer_users", user: @user, status: "completed", filename: "asml.csv", config: {params: {customer_id: asml.id}})
        Mensa::Export.create!(table_name: "customer_users", user: @user, status: "completed", filename: "sap.csv", config: {params: {customer_id: sap.id}})

        get exports_path_with_params("customer_users", customer_id: asml.id),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_match Mensa::Export.list_dom_id("customer_users", @user, params: {customer_id: asml.id}), response.body
        assert_match "asml.csv", response.body
        assert_no_match "sap.csv", response.body
      end

      test "destroy refreshes the list of the export's params" do
        customer = customers(:asml)
        export = Mensa::Export.create!(table_name: "customer_users", user: @user, status: "completed", config: {params: {customer_id: customer.id}})

        delete mensa.table_export_path("customer_users", export),
          headers: {"Accept" => "text/vnd.turbo-stream.html"}

        assert_response :success
        assert_not Mensa::Export.exists?(export.id)
        assert_match Mensa::Export.list_dom_id("customer_users", @user, params: {customer_id: customer.id}), response.body
        assert_match Mensa::Export.badge_dom_id("customer_users", @user, params: {customer_id: customer.id}), response.body
      end

      private

      # The exports URL as the table component renders it.
      def exports_path_with_params(table_name, **table_params)
        Mensa::TableParams.append_to(mensa.table_exports_path(table_name), table_params)
      end
    end
  end
end
