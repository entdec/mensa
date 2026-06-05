require "test_helper"
require "csv"
require "turbo/broadcastable/test_helper"

module Mensa
  class ExportJobTest < ActiveJob::TestCase
    include Turbo::Broadcastable::TestHelper

    setup do
      @user = User.first
    end

    test "generates a CSV, attaches it and marks the export completed" do
      export = Mensa::Export.create!(table_name: "users", user: @user, format: "csv_excel", scope: "all")

      Mensa::ExportJob.perform_now(export.id)
      export.reload

      assert export.completed?
      assert export.asset.attached?
      assert_equal "text/csv", export.asset.content_type
      assert_match(/users_export_.*\.csv\z/, export.filename)

      data = export.asset.download.force_encoding("UTF-8")
      assert data.start_with?("\uFEFF"), "expected a UTF-8 BOM for the Excel format"

      table = Mensa.for_name("users")
      rows = CSV.parse(data.delete_prefix("\uFEFF"))
      assert_equal table.display_columns.map { it.name.to_s }, rows.first
      assert_equal User.count, rows.length - 1
    end

    test "plain CSV format omits the BOM" do
      export = Mensa::Export.create!(table_name: "users", user: @user, format: "plain_csv", scope: "all")

      Mensa::ExportJob.perform_now(export.id)

      assert_not export.reload.asset.download.force_encoding("UTF-8").start_with?("\uFEFF")
    end

    test "current_page scope only exports the visible page" do
      export = Mensa::Export.create!(table_name: "users", user: @user, format: "plain_csv", scope: "current_page")

      Mensa::ExportJob.perform_now(export.id)

      rows = CSV.parse(export.reload.asset.download)
      # The header plus a single (paginated) page of records, which is fewer
      # than the total number of users.
      assert_operator rows.length - 1, :<, User.count
    end

    test "applies the captured filter configuration" do
      export = Mensa::Export.create!(
        table_name: "users",
        user: @user,
        format: "plain_csv",
        scope: "all",
        config: {filters: {role: {value: "admin", operator: "equals"}}}
      )

      Mensa::ExportJob.perform_now(export.id)

      rows = CSV.parse(export.reload.asset.download)
      assert_equal User.where(role: "admin").count, rows.length - 1
    end

    test "invokes the export callbacks with the export" do
      started = nil
      completed = nil
      Mensa.config.callbacks[:export_started] = ->(export) { started = export }
      Mensa.config.callbacks[:export_complete] = ->(export) { completed = export }

      export = Mensa::Export.create!(table_name: "users", user: @user, format: "plain_csv", scope: "all")
      Mensa::ExportJob.perform_now(export.id)

      assert_equal export.id, started&.id
      assert_equal export.id, completed&.id
    ensure
      Mensa.reset_config!
    end

    test "broadcasts the refreshed badge and downloads list when finished" do
      export = Mensa::Export.create!(table_name: "users", user: @user, format: "plain_csv", scope: "all")
      stream = Mensa::Export.stream_name("users", @user)

      broadcasts = capture_turbo_stream_broadcasts(stream) do
        Mensa::ExportJob.perform_now(export.id)
      end

      assert_equal 2, broadcasts.size
      assert broadcasts.any? { |b| b.to_s.include?(Mensa::Export.badge_dom_id("users", @user)) }
      assert broadcasts.any? { |b| b.to_s.include?(Mensa::Export.list_dom_id("users", @user)) }
    end

    test "does nothing for an unknown export id" do
      assert_nothing_raised do
        Mensa::ExportJob.perform_now(SecureRandom.uuid)
      end
    end
  end
end
