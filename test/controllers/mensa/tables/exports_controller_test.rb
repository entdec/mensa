require "test_helper"

module Mensa
  module Tables
    class ExportsControllerTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper

      setup do
        @user = User.first
      end

      test "create persists an export and enqueues the job" do
        assert_difference -> { Mensa::Export.count }, 1 do
          assert_enqueued_with(job: Mensa::ExportJob) do
            post mensa.table_exports_path("users"),
              params: {export_format: "plain_csv", scope: "all", query: "", filters: {role: {value: "admin", operator: "is"}}},
              as: :json
          end
        end

        assert_response :created

        export = Mensa::Export.order(:created_at).last
        assert_equal "users", export.table_name
        assert_equal "plain_csv", export.format
        assert_equal "all", export.scope
        assert_equal @user, export.user
        assert_equal "admin", export.config.dig("filters", "role", "value")
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
    end
  end
end
