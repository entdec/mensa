require "test_helper"

class Mensa::HumanNameTest < ActiveSupport::TestCase
  test "a table is called by its model, in the plural, as the export dialog's title says it" do
    table = UsersTable.new
    table.name = :users

    assert_equal "users", table.human_name
    assert_equal "Export users", I18n.t("mensa.exports.title", table: table.human_name)
  end
end
