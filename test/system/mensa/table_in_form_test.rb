require "application_system_test_case"

# The users table rendered inside a host <form>, like a tab on an edit page.
class TableInFormTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    visit form_embedded_users_url
    clear_local_storage
  end

  teardown do
    Mensa::TableView.where(table_name: "users").destroy_all
    Mensa::Export.destroy_all
  end

  test "the host form submits with only its own fields" do
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    # Change every export control so they would be sent if they leaked.
    open_export_dialog
    within "dialog.mensa-table__export-dialog" do
      find("input[data-mensa-export-field='scope'][value='current_page']").choose
      find("input[data-mensa-export-field='export_format'][value='plain_csv']").choose
      find("input[data-mensa-export-field='repeat_mode'][value='repeating']").choose
      find("select[data-mensa-export-field='repeat']").select("weekly")
      click_button "Cancel"
    end

    assert_empty all("#host-form form", visible: :all)
    assert_empty all("#host-form .mensa-table [required]", visible: :all)

    fill_in "Before table", with: "before"
    fill_in "After table", with: "after"
    click_button "Create Customer"

    assert_selector "h1", text: "Host form submitted", wait: 10
    submitted = JSON.parse(find("#submitted-params").text)
    assert_equal({"before_table" => "before", "after_table" => "after"}, submitted["host"])
    assert_equal %w[commit host], submitted.keys.sort
  end

  test "saving a view with Enter" do
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    open_save_view_dialog
    within("dialog.mensa-table__save-view-dialog") do
      input = find("[data-mensa-table-target='saveViewName']")
      input.set("Saved with enter")
      input.send_keys(:enter)
    end

    assert_selector ".mensa-table__views__trigger-label", text: "Saved with enter", wait: 5
    assert_current_path form_embedded_users_path
    assert_equal ["Saved with enter"], Mensa::TableView.where(table_name: "users").pluck(:name)
  end

  test "saving a view with the button" do
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    open_save_view_dialog
    within("dialog.mensa-table__save-view-dialog") do
      find("[data-mensa-table-target='saveViewName']").set("Saved with button")
      click_button "Save"
    end

    assert_selector ".mensa-table__views__trigger-label", text: "Saved with button", wait: 5
    assert_current_path form_embedded_users_path
    assert_equal ["Saved with button"], Mensa::TableView.where(table_name: "users").pluck(:name)
  end

  test "saving a view without a name shows a validation message" do
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    open_save_view_dialog
    within("dialog.mensa-table__save-view-dialog") do
      input = find("[data-mensa-table-target='saveViewName']")
      input.send_keys(:enter)
      assert_equal "Please enter a name for this view.", input.evaluate_script("this.validationMessage")

      input.send_keys("x")
      assert_equal "", input.evaluate_script("this.validationMessage")

      input.set("")
      click_button "Save"
      assert_equal "Please enter a name for this view.", input.evaluate_script("this.validationMessage")
    end

    assert_selector "dialog.mensa-table__save-view-dialog[open]"
    assert_current_path form_embedded_users_path
    assert_equal 0, Mensa::TableView.where(table_name: "users").count
  end

  test "renaming a view with Enter, with the button and without a name" do
    view = Mensa::TableView.create!(table_name: "users", name: "Before rename", config: {}, user: User.first)
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    open_rename_dialog(view)
    within("dialog.mensa-table__views__rename-dialog") do
      input = find("[data-mensa-views-target='renameInput']")
      input.set("")
      click_button "Rename"
      assert_equal "Please enter a name for this view.", input.evaluate_script("this.validationMessage")
      input.set("Renamed with enter")
      input.send_keys(:enter)
    end
    assert_selector "li[data-mensa-views-target='view']", text: "Renamed with enter", visible: :all, wait: 5
    assert_equal "Renamed with enter", view.reload.name

    open_rename_dialog(view)
    within("dialog.mensa-table__views__rename-dialog") do
      input = find("[data-mensa-views-target='renameInput']")
      assert_equal "", input.evaluate_script("this.validationMessage")
      input.set("Renamed with button")
      click_button "Rename"
    end
    assert_selector "li[data-mensa-views-target='view']", text: "Renamed with button", visible: :all, wait: 5
    assert_equal "Renamed with button", view.reload.name
    assert_current_path form_embedded_users_path
  end

  test "creating a repeating export and deleting it" do
    visit form_embedded_users_url
    assert_selector "tbody tr", wait: 10

    open_export_dialog
    within "dialog.mensa-table__export-dialog" do
      find("input[data-mensa-export-field='scope'][value='current_page']").choose
      find("input[data-mensa-export-field='export_format'][value='plain_csv']").choose
      find("input[data-mensa-export-field='repeat_mode'][value='repeating']").choose
      find("select[data-mensa-export-field='repeat']").select("weekly")
      click_button "Export"
    end

    assert_selector ".mensa-table__export-dialog__item-repeat", wait: 10
    export = Mensa::Export.for_table("users").sole
    assert_equal ["current_page", "plain_csv", "weekly"], [export.scope, export.format, export.repeat]
    assert_current_path form_embedded_users_path

    find(".mensa-table__export-dialog__delete").click
    assert_selector ".mensa-table__export-dialog__empty", wait: 10
    assert_not Mensa::Export.exists?(export.id)
    assert_current_path form_embedded_users_path
  end

  private

  # Adds a filter so the Save button shows, then opens the save-view dialog.
  def open_save_view_dialog
    find(".mensa-table__search-bar__input").click
    find("[data-filter-column-name='role']", wait: 3).click
    find("[data-mensa-add-filter-target='valueOption'][data-value='admin']", wait: 3).click
    assert_selector ".mensa-filter-pill", wait: 3

    find("[data-mensa-table-target='saveSimple']", wait: 3).click
    assert_selector "dialog.mensa-table__save-view-dialog[open]", wait: 5
  end

  def open_rename_dialog(view)
    find(".mensa-table__views__trigger").click
    assert_selector ".mensa-table__views__dropdown:not(.hidden)", wait: 3
    find("li[data-view-id='#{view.id}']").hover
    find("li[data-view-id='#{view.id}'] .mensa-table__views__option-menu").click
    find("[data-action='mensa-views#renameView']", wait: 3).click
    assert_selector "dialog.mensa-table__views__rename-dialog[open]", wait: 5
  end

  def open_export_dialog
    find("[data-action='mensa-table#export']").click
    assert_selector "dialog.mensa-table__export-dialog[open]", wait: 10
  end
end
