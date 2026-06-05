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
    end

    test "rejects unknown statuses" do
      export = Mensa::Export.new(table_name: "users", status: "bogus")
      assert_not export.valid?
    end

    test "for_table and for_user scope by table and user" do
      mine = Mensa::Export.create!(table_name: "users", user: @user)
      Mensa::Export.create!(table_name: "users", user: User.where.not(id: @user.id).first)
      Mensa::Export.create!(table_name: "customers", user: @user)

      result = Mensa::Export.for_table("users").for_user(@user)
      assert_equal [mine.id], result.pluck(:id)
    end

    test "completed_count only counts completed exports for the table/user" do
      Mensa::Export.create!(table_name: "users", user: @user, status: "completed")
      Mensa::Export.create!(table_name: "users", user: @user, status: "pending")

      assert_equal 1, Mensa::Export.completed_count("users", @user)
      assert_equal 0, Mensa::Export.completed_count("customers", @user)
    end

    test "downloadable? requires a completed export with an attached asset" do
      export = Mensa::Export.create!(table_name: "users", user: @user, status: "completed")
      assert_not export.downloadable?

      export.asset.attach(io: StringIO.new("a,b\n1,2\n"), filename: "x.csv", content_type: "text/csv")
      assert export.downloadable?
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
