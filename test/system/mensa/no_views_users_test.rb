require "application_system_test_case"

class NoViewsUsersTest < ApplicationSystemTestCase
  setup do
    Mensa::TableView.where(table_name: "no_views_users").destroy_all

    visit no_views_users_url
    execute_script("localStorage.clear()")
    visit no_views_users_url
  end

  teardown do
    Mensa::TableView.where(table_name: "no_views_users").destroy_all
  end

  test "saving the first custom view reveals the views dropdown" do
    assert_selector "tbody tr", wait: 15
    assert_no_selector ".mensa-table__views"

    save_custom_view("Admins only")

    assert_selector ".mensa-table__views__trigger-label", text: "Admins only", wait: 10
    open_views_dropdown
    assert_selector "li[data-mensa-views-target='view']", text: "Admins only"
  end

  test "deleting the only custom view hides the views dropdown again" do
    assert_selector "tbody tr", wait: 15
    assert_no_selector ".mensa-table__views"

    save_custom_view("Temporary view")
    assert_selector ".mensa-table__views__trigger-label", text: "Temporary view", wait: 10

    open_views_dropdown
    menu = find("li[data-mensa-views-target='view']", text: "Temporary view")
      .find(".mensa-table__views__option-menu", visible: :all)
    execute_script("arguments[0].dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }))", menu.native)
    assert_selector ".mensa-table__views__submenu:not(.hidden)", wait: 10

    delete_button = find("[data-action='mensa-views#deleteView']", visible: :all, wait: 10)
    accept_confirm do
      execute_script("arguments[0].dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }))", delete_button.native)
    end

    assert_no_selector ".mensa-table__views", wait: 10
  end

  private

  def save_custom_view(name)
    fill_in_search("Oliver")
    find("[data-mensa-table-target='saveSimple']:not(.hidden)", wait: 10).click

    within("dialog.mensa-table__save-view-dialog") do
      find("[data-mensa-table-target='saveViewName']").set(name)
      click_button "Save"
    end
  end

  def fill_in_search(query)
    input = find("input.mensa-table__search-bar__input")
    input.set(query)
    input.send_keys(:return)
  end

  def open_views_dropdown
    find(".mensa-table__views__trigger").click
    assert_selector ".mensa-table__views__dropdown:not(.hidden)", wait: 10
  end
end
