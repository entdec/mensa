require "application_system_test_case"

class NonCustomViewsTest < ApplicationSystemTestCase
  test "persisted filter state does not show save controls when custom views are disabled" do
    visit non_custom_view_users_url
    assert_selector "tbody tr", wait: 15

    # Filters are stored per page, under the key the table renders.
    execute_script <<~JS
      const key = document.querySelector("[data-mensa-filter-pill-list-storage-key-value]")
        .dataset.mensaFilterPillListStorageKeyValue;
      localStorage.setItem(
        `mensa:filters:${key}`,
        JSON.stringify({ role: { operator: "is", value: "admin" } })
      )
    JS

    visit non_custom_view_users_url
    assert_selector "tbody tr", wait: 15
    assert_selector ".mensa-filter-pill", wait: 10
    assert_selector ".mensa-table__save-reset:not(.hidden)", wait: 10

    within ".mensa-table__save-reset:not(.hidden)" do
      assert_selector "button[title='Reset']"
      assert_no_text "Save"
    end
    assert_no_selector "[data-mensa-table-target='saveSimple']"
    assert_no_selector "[data-mensa-table-target='saveSplit']"
    assert_no_selector "button[data-action='mensa-table#saveAsNewView']"
  end
end
