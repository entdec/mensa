require "test_helper"

# A Mensa table can be rendered inside a host <form>. HTML has no nested
# forms, so Mensa must not render <form> elements, `required` inputs or named
# controls that the host form would pick up.
class TableInFormTest < ActionDispatch::IntegrationTest
  setup do
    # A listed export renders its delete button too.
    Mensa::Export.create!(table_name: "users", user: User.first, status: "completed", filename: "users_export.csv")
  end

  test "the table renders no forms inside a host form" do
    get form_embedded_users_path

    assert_response :success
    # Count in the raw HTML: an HTML parser silently drops nested <form> tags.
    assert_equal 1, response.body.scan(/<form\b/).size, "Only the host form should be rendered"

    table = Nokogiri::HTML(response.body).at_css(".mensa-table")
    assert table, "Expected a mensa table"
    assert table.at_css(".mensa-table__save-view-dialog"), "Expected the save-view dialog"
    assert table.at_css(".mensa-table__views__rename-dialog"), "Expected the rename dialog"
    assert table.at_css(".mensa-table__export-dialog__delete"), "Expected an export delete button"

    assert_empty table.css("[required]").map(&:to_html)
    assert_empty table.css("button:not([type])").map(&:to_html)
    assert_empty table.css("button[type=submit], input[type=submit]").map(&:to_html)

    # Named controls must not belong to a host form.
    owned = table.css("input[name], select[name], textarea[name]").reject { it["form"].present? }
    assert_empty owned.map(&:to_html)
  end

  test "export controls point at a form that does not exist and have per-table names" do
    get form_embedded_users_path

    doc = Nokogiri::HTML(response.body)
    controls = doc.css(".mensa-table__export-dialog [data-mensa-export-field]")
    assert_equal %w[export_format repeat repeat_mode scope], controls.map { it["data-mensa-export-field"] }.uniq.sort

    form_ids = controls.map { it["form"] }.uniq
    assert_equal 1, form_ids.size
    assert_nil doc.at_css("##{form_ids.first}"), "The form attribute must not match an element"
    controls.each { assert it["name"].start_with?("#{form_ids.first}-") }
  end
end
