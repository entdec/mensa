require "application_system_test_case"
require "csv"
require "net/http"
require "stringio"
require "zip"

class ExportsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
    Mensa::Export.destroy_all
  end

  test "downloads a users table export" do
    visit users_url
    assert_selector "tbody tr", wait: 10

    create_plain_csv_export
    export = perform_latest_export("users")

    assert_selector ".mensa-table__export-dialog__download", text: /Download|Downloaden/, wait: 10
    response = download_response

    assert_equal "200", response.code
    assert_equal "text/csv", response.content_type
    assert_match(/attachment/, response["Content-Disposition"])
    assert_match(/#{Regexp.escape(export.filename)}/, response["Content-Disposition"])

    rows = CSV.parse(response.body)
    table = Mensa.for_name("users")
    assert_equal table.display_columns.map { it.name.to_s }, rows.first
    assert_equal User.count, rows.length - 1
  end

  test "downloads and opens a password protected users export" do
    visit users_export_with_password_index_url
    assert_selector "tbody tr", wait: 10

    create_plain_csv_export
    export = perform_latest_export("users_export_with_password")

    assert_equal "application/zip", export.asset.content_type
    assert_predicate export.password, :present?
    assert_selector ".mensa-table__export-dialog__item-password-value", text: export.password, wait: 10
    assert_selector ".mensa-table__export-dialog__item-password-copy[aria-label='Copy password']"
    assert_selector ".mensa-table__export-dialog__download", text: /Download|Downloaden/, wait: 10

    execute_script(<<~JS)
      Object.defineProperty(navigator, "clipboard", {
        configurable: true,
        value: { writeText: (text) => { window.__copiedPassword = text; return Promise.resolve(); } }
      });
    JS
    find(".mensa-table__export-dialog__item-password-copy").click
    assert_equal export.password, evaluate_script("window.__copiedPassword")

    response = download_response

    assert_equal "200", response.code
    assert_equal "application/zip", response.content_type
    assert_match(/attachment/, response["Content-Disposition"])
    assert_match(/#{Regexp.escape(export.filename)}/, response["Content-Disposition"])

    Zip::InputStream.open(StringIO.new(response.body), decrypter: Zip::TraditionalDecrypter.new(export.password)) do |zip|
      entry = zip.get_next_entry
      assert_equal export.filename.sub(/\.zip\z/, ".csv"), entry.name

      rows = CSV.parse(zip.read)
      table = Mensa.for_name("users_export_with_password")
      assert_equal table.display_columns.map { it.name.to_s }, rows.first
      assert_equal User.count, rows.length - 1
    end
  end

  private

  def create_plain_csv_export
    find("[data-action='mensa-table#export']").click
    assert_selector "dialog.mensa-table__export-dialog[open]", wait: 10

    within "dialog.mensa-table__export-dialog" do
      find("input[name='export_format'][value='plain_csv']").choose
      find("button[type='submit']").click
    end
  end

  def perform_latest_export(table_name)
    export = wait_for_export(table_name)

    perform_enqueued_jobs
    export.reload

    assert export.completed?
    assert export.asset.attached?
    export
  end

  def wait_for_export(table_name)
    deadline = Capybara.default_max_wait_time.seconds.from_now

    loop do
      export = Mensa::Export.for_table(table_name).recent.first
      return export if export
      raise "Timed out waiting for #{table_name} export to be created" if Time.current >= deadline

      sleep 0.05
    end
  end

  def download_response
    link = find(".mensa-table__export-dialog__download", text: /Download|Downloaden/, wait: 10)
    uri = URI.join(page.current_url, link[:href])
    Net::HTTP.get_response(uri)
  end
end
