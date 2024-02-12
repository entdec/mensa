require "application_system_test_case"

class UsersTablesTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit users_url

    assert_selector "h1", text: "UsersTable"
  end
end
