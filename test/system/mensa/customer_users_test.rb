require "application_system_test_case"
require "csv"
require "net/http"

# CustomerUsersTable can only be built with params[:customer_id], so these
# tests fail if the params don't reach the filter and export endpoints.
class CustomerUsersTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    @customer = customers(:asml)
    @table_params = {customer_id: @customer.id}
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
    Mensa::Export.destroy_all
  end

  test "renders only the customer's users" do
    visit customer_users_url(customer_id: @customer.id)

    assert_selector "tbody tr", count: @customer.users.count, wait: 10
    assert_selector "tbody", text: users(:asml_user).last_name
    assert_no_selector "tbody", text: users(:sap_user).last_name
  end

  test "filters a table that needs params" do
    visit customer_users_url(customer_id: @customer.id)
    assert_selector "tbody tr", wait: 10

    find(".mensa-table__search-bar__input").click
    find("[data-filter-column-name='role']", wait: 3).click
    find("[data-mensa-add-filter-target='valueOption'][data-value='admin']", wait: 3).click

    assert_selector ".mensa-filter-pill", wait: 3
    assert_selector "tbody tr", count: @customer.users.where(role: "admin").count, wait: 3
  end

  test "exports all rows of a table that needs params" do
    export = create_export(scope: "all")

    assert_equal({"customer_id" => @customer.id}, export.table_params)
    rows = CSV.parse(download_response.body)
    assert_equal @customer.users.count, rows.length - 1
  end

  test "exports the current page of a table that needs params" do
    export = create_export(scope: "current_page")

    assert_equal "current_page", export.scope
    rows = CSV.parse(download_response.body)
    assert_equal @customer.users.count, rows.length - 1
  end

  private

  def create_export(scope:)
    visit customer_users_url(customer_id: @customer.id)
    assert_selector "tbody tr", wait: 10

    find("[data-action='mensa-table#export']").click
    assert_selector "dialog.mensa-table__export-dialog[open]", wait: 10
    within "dialog.mensa-table__export-dialog" do
      find("input[name='scope'][value='#{scope}']").choose
      find("input[name='export_format'][value='plain_csv']").choose
      find("button[type='submit']").click
    end

    export = wait_for_export
    perform_enqueued_jobs
    export.reload
    assert export.completed?
    export
  end

  def wait_for_export
    deadline = Capybara.default_max_wait_time.seconds.from_now

    loop do
      export = Mensa::Export.for_table("customer_users", params: @table_params).recent.first
      return export if export
      raise "Timed out waiting for the customer_users export to be created" if Time.current >= deadline

      sleep 0.05
    end
  end

  def download_response
    link = find(".mensa-table__export-dialog__download", text: /Download|Downloaden/, wait: 10)
    Net::HTTP.get_response(URI.join(page.current_url, link[:href]))
  end
end
