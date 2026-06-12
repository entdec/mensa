require "test_helper"

module Mensa
  class ExportTest < ActiveSupport::TestCase
    setup do
      @user = User.first
    end

    test "requires a table name" do
      export = Mensa::Export.new(table_name: nil)
      assert_not export.valid?
      assert_includes export.errors[:table_name], "can't be blank"
    end

    test "defaults to a pending status" do
      export = Mensa::Export.create!(table_name: "users", user: @user)
      assert export.pending?
      assert_not export.completed?
      assert_not export.downloadable?
      assert_equal "", export.repeat
    end

    test "rejects unknown statuses" do
      export = Mensa::Export.new(table_name: "users", status: "bogus")
      assert_not export.valid?
    end

    test "rejects unknown repeat values" do
      export = Mensa::Export.new(table_name: "users", repeat: "bogus")
      assert_not export.valid?
    end

    test "for_table and for_user scope by table and user" do
      mine = Mensa::Export.create!(table_name: "users", user: @user)
      Mensa::Export.create!(table_name: "users", user: User.where.not(id: @user.id).first)
      Mensa::Export.create!(table_name: "customers", user: @user)

      result = Mensa::Export.for_table("users").for_user(@user)
      assert_equal [mine.id], result.pluck(:id)
    end

    test "completed_count only counts exports with a downloadable asset for the table/user" do
      completed_without_asset = Mensa::Export.create!(table_name: "users", user: @user, status: "completed")
      downloadable = Mensa::Export.create!(table_name: "users", user: @user, status: "completed")
      downloadable.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "x.csv", content_type: "text/csv")
      Mensa::Export.create!(table_name: "users", user: @user, status: "pending")

      assert_not completed_without_asset.downloadable?
      assert downloadable.downloadable?
      assert_equal 1, Mensa::Export.completed_count("users", @user)
      assert_equal 0, Mensa::Export.completed_count("customers", @user)
    end

    test "downloadable? requires a completed export with an attached asset" do
      export = Mensa::Export.create!(table_name: "users", user: @user, status: "completed")
      assert_not export.downloadable?

      export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "x.csv", content_type: "text/csv")
      assert export.downloadable?
    end

    test "next_repeat_run_at is calculated from the last repeat run" do
      export = Mensa::Export.create!(
        table_name: "users",
        user: @user,
        repeat: "monthly",
        last_repeat_run_at: Time.zone.parse("2026-01-15 10:00:00")
      )

      assert_equal Time.zone.parse("2026-02-15 10:00:00"), export.next_repeat_run_at
    end

    test "repeat_due? ignores pending and processing exports" do
      pending_export = Mensa::Export.create!(table_name: "users", user: @user, repeat: "daily", status: "pending")
      processing_export = Mensa::Export.create!(table_name: "users", user: @user, repeat: "daily", status: "processing")

      assert_not pending_export.repeat_due?(Time.current + 2.days)
      assert_not processing_export.repeat_due?(Time.current + 2.days)
    end

    test "repeating? and repeat labels reflect the translated repeat interval" do
      export = Mensa::Export.create!(table_name: "users", user: @user, repeat: "weekly")

      assert export.repeating?
      assert_equal "weekly", I18n.with_locale(:en) { export.repeat_interval_label }
      assert_equal "wekelijks", I18n.with_locale(:nl) { export.repeat_interval_label }
      assert_equal "Repeats weekly", I18n.with_locale(:en) { export.repeat_label }
      assert_equal "Herhaalt wekelijks", I18n.with_locale(:nl) { export.repeat_label }
      assert_not Mensa::Export.create!(table_name: "users", user: @user).repeating?
    end

    test "token, stream_name and dom ids are stable and parameterized" do
      token = Mensa::Export.token("admin/users", @user)
      assert_equal "admin-users-#{@user.id}", token
      assert_equal "mensa-exports-#{token}", Mensa::Export.stream_name("admin/users", @user)
      assert_equal "mensa-export-badge-#{token}", Mensa::Export.badge_dom_id("admin/users", @user)
      assert_equal "mensa-export-list-#{token}", Mensa::Export.list_dom_id("admin/users", @user)
    end

    test "token falls back to anonymous without a user" do
      assert_equal "users-anonymous", Mensa::Export.token("users", nil)
    end
  end
end
