require "application_system_test_case"

class UsersTablesTest < ApplicationSystemTestCase
  # Row-action buttons are rendered before the data cells (row_actions_position = :front).
  # Column layout: td1=checkbox, td2=actions, td3=first_name, td4=last_name,
  #                td5=email, td6=role, td7=customer_name
  FIRST_NAME_COL = "td:nth-child(3)"
  LAST_NAME_COL = "td:nth-child(4)"
  EMAIL_COL = "td:nth-child(5)"
  ROLE_COL = "td:nth-child(6)"

  setup do
    # Visit the page first so we can clear this origin's localStorage,
    # preventing state from leaking between tests.
    visit users_url
    execute_script("localStorage.clear()")
  end

  teardown do
    Mensa::TableView.where(table_name: "users").destroy_all
  end

  # ---------------------------------------------------------------------------
  # Row links
  # ---------------------------------------------------------------------------

  test "clicking a row navigates to the row's linked path" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    first_row = first("tbody tr:nth-child(1)")
    expected_path = first_row["href"]
    id = first_row.find("td input").value
    assert expected_path.present?, "Row should carry an href"
    assert_equal edit_user_path(id), expected_path
  end

  test "every row links to a distinct edit path" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    hrefs = all("tbody tr").map { |tr| tr["href"] }
    assert hrefs.all?(&:present?), "Every row should have an href"
    assert_equal hrefs.length, hrefs.uniq.length, "Each row should link to a different path"
  end

  # ---------------------------------------------------------------------------
  # Sorting
  # ---------------------------------------------------------------------------

  test "clicking a sortable column header sorts rows ascending" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 3

    first_names = all("tbody tr #{FIRST_NAME_COL}").map(&:text)
    assert_equal first_names, User.order(:first_name).limit(first_names.length).pluck(:first_name)
    "First names should be in ascending order after sort"
  end

  test "clicking the same sortable column header a second time sorts descending" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 3
    first_asc = first("tbody tr #{FIRST_NAME_COL}").text

    find("thead a", text: "First name").click
    assert_selector "tbody tr", wait: 3

    last_names = all("tbody tr #{FIRST_NAME_COL}").map(&:text)
    assert_equal last_names, User.order(first_name: :desc).limit(last_names.length).pluck(:first_name),
      "First names should be in descending order after second click"

    first_desc = last_names.first
    assert_not_equal first_asc, first_desc,
      "Ascending and descending first rows should differ"
  end

  test "sorting by last name orders rows lexicographically" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    find("thead a", text: "Last name").click
    assert_selector "tbody tr", wait: 3

    last_names = all("tbody tr #{LAST_NAME_COL}").map(&:text)
    assert_equal last_names, User.order(:last_name).limit(last_names.length).pluck(:last_name)
  end

  test "sorting by email orders rows alphabetically" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    find("thead a", text: "Email").click
    assert_selector "tbody tr", wait: 3

    emails = all("tbody tr #{EMAIL_COL}").map(&:text)
    assert_equal emails, emails.sort
  end

  test "clicking a sort link three times cycles asc → desc → unsorted" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Ascending
    find("thead a", text: "Last name").click
    assert_selector "tbody tr", wait: 3
    asc_first = first("tbody tr #{LAST_NAME_COL}").text

    # Descending
    find("thead a", text: "Last name").click
    assert_selector "tbody tr", wait: 3
    desc_first = first("tbody tr #{LAST_NAME_COL}").text

    assert_not_equal asc_first, desc_first

    # Remove sort (third click)
    find("thead a", text: "Last name").click
    assert_selector "tbody tr", wait: 3

    # After removing sort, clicking once more should go back to ascending
    find("thead a", text: "Last name").click
    assert_selector "tbody tr", wait: 3
    asc_again_first = first("tbody tr #{LAST_NAME_COL}").text

    assert_equal asc_first, asc_again_first,
      "After sort-cycle completes, ascending first row should match the first ascending sort"
  end

  # ---------------------------------------------------------------------------
  # Filtering — single column
  # ---------------------------------------------------------------------------

  test "adding a role filter shows only rows with the selected role" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Only one admin user exists in the fixtures (Peter Wennink / asml_user)
    add_filter(column: "role", value: "admin")

    assert_selector "tbody tr", count: 1
    assert_selector "tbody", text: "Wennink"
  end

  test "filter pill appears with correct column and value labels" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "user")

    assert_selector ".mensa-filter-pill__column", text: "Role"
    assert_selector ".mensa-filter-pill__value", text: "User"
  end

  test "clicking the remove button on a filter pill clears the filter" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "admin")
    assert_selector "tbody tr", count: 1

    remove_filter(column: "Role")
    assert_no_selector ".mensa-filter-pill", wait: 3
    # All 20 first-page rows should be back
    assert_selector "tbody tr", minimum: 20, wait: 3
  end

  # ---------------------------------------------------------------------------
  # Filtering — multiple columns (role filter + text search simultaneously)
  # ---------------------------------------------------------------------------

  test "a role filter combined with a text search narrows results further" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Apply role=user filter (32 matching users in fixtures)
    add_filter(column: "role", value: "user")

    # Two users are named "Oliver" (Zipse and Blume), both with role=user.
    # After the search, exactly those two rows should remain.
    fill_in_search("Oliver")

    assert_selector "tbody tr", text: "Oliver", wait: 3
    assert_selector "tbody tr", count: 2, wait: 5
    all("tbody tr").each { |tr| assert_includes tr.text, "Oliver" }
  end

  test "role filter combined with search rejects rows failing either condition" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Admin filter — only Peter Wennink (asml_user) matches
    add_filter(column: "role", value: "admin")
    assert_selector "tbody tr", count: 1, wait: 3

    # "Zipse" belongs to Oliver Zipse who has role=user, not admin
    fill_in_search("Zipse")

    assert_no_selector "tbody tr", wait: 3
  end

  # ---------------------------------------------------------------------------
  # Editing existing filters
  # ---------------------------------------------------------------------------

  test "clicking a filter pill reopens the value popover pre-filled with the current value" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "user")
    assert_selector ".mensa-filter-pill"

    find(".mensa-filter-pill__chip").click
    # The value popover re-opens with "user" pre-selected
    assert_selector "[data-mensa-add-filter-target='valueOption'][data-value='user'][data-selected='true']",
      wait: 3
  end

  test "editing a filter pill and selecting a new value updates the table" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "user")
    assert_selector ".mensa-filter-pill__value", text: "User"

    # Reopen the pill and change to "guest"
    find(".mensa-filter-pill__chip").click
    find("[data-mensa-add-filter-target='valueOption'][data-value='guest']", wait: 3).click

    assert_selector ".mensa-filter-pill__value", text: "Guest", wait: 3
    # Christian Klein (sap_user) is the sole guest
    assert_selector "tbody tr", count: 1, wait: 3
    assert_selector "tbody", text: "Klein"
  end

  test "changing the filter operator to 'not is' inverts the filtered result set" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Filter to admin only (1 row)
    add_filter(column: "role", value: "admin")
    assert_selector "tbody tr", count: 1

    # Reopen the pill and switch to "Is not"
    find(".mensa-filter-pill__chip").click
    find("[data-mensa-add-filter-target='operatorOption'][data-operator='isnt']",
      wait: 3).click

    # Everyone except the admin should now appear (≥2 rows)
    assert_selector "tbody tr", minimum: 2, wait: 3
    assert_no_selector "tbody", text: "Wennink"
  end

  # ---------------------------------------------------------------------------
  # Column hiding
  # ---------------------------------------------------------------------------

  test "hiding a column via the column customizer removes it from the table header" do
    visit users_url
    assert_selector "thead th", text: "Role", wait: 3

    open_column_customizer
    toggle_column_visibility("role")

    assert_no_selector "thead th", text: "Role", wait: 3
  end

  test "toggling a hidden column visible restores it in the table header" do
    visit users_url
    assert_selector "thead th", text: "Role", wait: 3

    open_column_customizer
    toggle_column_visibility("role")
    assert_no_selector "thead th", text: "Role", wait: 3

    # Toggle it back on
    toggle_column_visibility("role")
    assert_selector "thead th", text: "Role", wait: 3
  end

  test "column visibility state survives a page reload via localStorage" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    open_column_customizer
    toggle_column_visibility("role")
    assert_no_selector "thead th", text: "Role", wait: 3

    find("body").click # close popover
    visit users_url
    assert_no_selector "thead th", text: "Role", wait: 3
  end

  # ---------------------------------------------------------------------------
  # Column ordering
  # ---------------------------------------------------------------------------

  test "dragging a column in the customizer reorders it in the table header" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    open_column_customizer

    # Move "Email" before "First name" using simulated HTML5 drag events
    email_row = find("[data-column-name='email']")
    first_name_row = find("[data-column-name='first_name']")
    drag_html5(email_row, first_name_row, above: true)

    assert_selector "thead th:nth-child(3)", text: "Email", wait: 3

    headers = table_headers
    email_idx = headers.index { |h| h.include?("Email") }
    first_name_idx = headers.index { |h| h.include?("First name") }

    assert email_idx < first_name_idx,
      "Email (at #{email_idx}) should appear before First name (at #{first_name_idx}) after drag"
  end

  test "dragged column order persists to localStorage and survives a page reload" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    open_column_customizer
    email_row = find("[data-column-name='email']")
    first_name_row = find("[data-column-name='first_name']")
    drag_html5(email_row, first_name_row, above: true)
    assert_selector "thead th", wait: 3

    visit users_url
    assert_selector "thead th:nth-child(3)", text: "Email", wait: 3

    headers = table_headers
    email_idx = headers.index { |h| h.include?("Email") }
    first_name_idx = headers.index { |h| h.include?("First name") }

    assert email_idx < first_name_idx,
      "Column order should persist after page reload"
  end

  # ---------------------------------------------------------------------------
  # View creation
  # ---------------------------------------------------------------------------

  test "saving filters as a new view adds it to the views dropdown" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "admin")
    # notifyUnsavedState removes .hidden from both saveResetButtons and saveSimple;
    # Capybara's default visibility check waits until the element becomes visible.
    find("[data-mensa-table-target='saveSimple']", wait: 3).click
    within("dialog.mensa-table__save-view-dialog") do
      find("[data-mensa-table-target='saveViewName']").set("Admins only")
      click_button "Save"
    end

    assert_selector ".mensa-table__views__trigger-label", text: "Admins only", wait: 3
    open_views_dropdown
    # Entry shouldn't be in the dropdown
    refute_selector "li[data-mensa-views-target='view'] span", text: "Admins only"
  end

  test "switching away from a custom view and back restores its filters" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    add_filter(column: "role", value: "admin")
    assert_selector "[data-mensa-table-target='saveSimple']:not(.hidden)", wait: 3
    find("[data-mensa-table-target='saveSimple']:not(.hidden)").click
    within("dialog.mensa-table__save-view-dialog") do
      find("[data-mensa-table-target='saveViewName']").set("Admins only")
      click_button "Save"
    end
    assert_selector ".mensa-table__views__trigger-label", text: "Admins only", wait: 3

    # Switch away to "All users"
    open_views_dropdown
    show_filters
    assert_selector ".mensa-table__views__trigger-label", text: "All users", wait: 3

    # Switch back to the custom view
    open_views_dropdown
    find("li[data-mensa-views-target='view']", text: "Admins only")
      .find("button[data-action='mensa-views#select']").click
    assert_selector ".mensa-table__views__trigger-label", text: "Admins only", wait: 3
    find("[data-mensa-table-target='eyeButton']").click
    assert_selector ".mensa-filter-pill__value", text: "Admin", wait: 3
  end

  # ---------------------------------------------------------------------------
  # View renaming
  # ---------------------------------------------------------------------------

  test "renaming a view updates its name in the dropdown and trigger label" do
    view = Mensa::TableView.create!(
      table_name: "users", name: "Before rename", config: {}, user: User.first
    )

    visit users_url
    assert_selector "tbody tr", wait: 3

    # Activate the custom view
    open_views_dropdown
    find("li[data-view-id='#{view.id}'] button[data-action='mensa-views#select']").click
    assert_selector ".mensa-table__views__trigger-label", text: "Before rename", wait: 3

    # Open the ellipsis submenu and rename
    open_views_dropdown
    find("li[data-view-id='#{view.id}']").hover
    find("li[data-view-id='#{view.id}'] .mensa-table__views__option-menu").click
    find("[data-action='mensa-views#renameView']", wait: 3).click

    within("dialog.mensa-table__views__rename-dialog") do
      find("[data-mensa-views-target='renameInput']").set("After rename")
      click_button "Rename"
    end

    assert_selector ".mensa-table__views__trigger-label", text: "After rename", wait: 3
    open_views_dropdown
    assert_selector "li[data-mensa-views-target='view']", text: "After rename"
    assert_no_selector "li[data-mensa-views-target='view']", text: "Before rename"
  end

  # ---------------------------------------------------------------------------
  # View deletion
  # ---------------------------------------------------------------------------

  test "deleting a view removes it from the dropdown" do
    view = Mensa::TableView.create!(
      table_name: "users", name: "Temporary view", config: {}, user: User.first
    )

    visit users_url
    assert_selector "tbody tr", wait: 3

    open_views_dropdown
    assert_selector "li[data-view-id='#{view.id}']"

    find("li[data-view-id='#{view.id}'] .mensa-table__views__option-menu", visible: false).click
    accept_confirm do
      find("[data-action='mensa-views#deleteView']", wait: 3).click
    end

    open_views_dropdown
    assert_no_selector "li[data-view-id='#{view.id}']", wait: 3
  end

  test "after deleting the active view the dropdown reverts to All users" do
    view = Mensa::TableView.create!(
      table_name: "users", name: "To be deleted", config: {}, user: User.first
    )

    visit users_url
    assert_selector "tbody tr", wait: 3

    # Activate the view
    open_views_dropdown
    find("li[data-view-id='#{view.id}'] button[data-action='mensa-views#select']").click
    assert_selector ".mensa-table__views__trigger-label", text: "To be deleted", wait: 3

    # Delete it
    open_views_dropdown
    find("li[data-view-id='#{view.id}']").hover
    find("li[data-view-id='#{view.id}'] .mensa-table__views__option-menu").click
    accept_confirm do
      find("[data-action='mensa-views#deleteView']", wait: 3).click
    end

    assert_selector ".mensa-table__views__trigger-label", text: "All users", wait: 3
  end

  # ---------------------------------------------------------------------------
  # Switching between views
  # ---------------------------------------------------------------------------

  test "switching to the Users built-in view hides the Role column" do
    visit users_url
    assert_selector "thead th", text: "Role", wait: 3

    open_views_dropdown
    find("li[data-view-id='users'] button[data-action='mensa-views#select']").click

    assert_selector ".mensa-table__views__trigger-label", text: "Users", wait: 3
    assert_selector ".mensa-filter-pill[data-view-filter='true']", visible: :all, wait: 3
    assert_selector "[data-mensa-table-target='eyeButton']:not(.hidden)", wait: 3
    assert_no_selector "thead th", text: "Role", wait: 3
  end

  test "switching from the Users view back to All users restores the Role column" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    open_views_dropdown
    find("li[data-view-id='users'] button[data-action='mensa-views#select']").click
    assert_no_selector "thead th", text: "Role", wait: 3

    open_views_dropdown
    find("[data-view-id='default'] button[data-action='mensa-views#select']").click

    assert_selector ".mensa-table__views__trigger-label", text: "All users", wait: 3
    assert_selector "thead th", text: "Role", wait: 3
  end

  test "the active view check indicator updates when switching views" do
    visit users_url
    assert_selector "tbody tr", wait: 3

    # Default view check is visible; users view check is invisible
    open_views_dropdown
    assert_selector "li[data-view-id='default'] .mensa-table__views__option-check:not(.invisible)"
    assert_selector "li[data-view-id='users'] .mensa-table__views__option-check.invisible", visible: false

    find("li[data-view-id='users'] button[data-action='mensa-views#select']").click
    open_views_dropdown

    assert_selector "li[data-view-id='users'] .mensa-table__views__option-check:not(.invisible)", wait: 3
    assert_selector "li[data-view-id='default'] .mensa-table__views__option-check.invisible", visible: false
  end

  private

  # Clicks the + button, selects a column, then selects a value to add a filter pill.
  def add_filter(column:, value:)
    find(".mensa-table__search-bar__input").click
    find("[data-filter-column-name='#{column}']", wait: 3).click
    find("[data-mensa-add-filter-target='valueOption'][data-value='#{value}']", wait: 3).click
    assert_selector ".mensa-filter-pill", wait: 3
  end

  def remove_filter(column:)
    find(".mensa-filter-pill__chip span.mensa-filter-pill__column", text: column).send(:parent).hover
    find(".mensa-filter-pill__remove").click
  end

  # Types a search query into the search bar and submits it with Enter.
  # The caller is responsible for waiting for the expected DOM change.
  def fill_in_search(query)
    input = find("input.mensa-table__search-bar__input")
    input.set(query)
    input.send_keys(:return)
  end

  def table_headers
    evaluate_script(<<~JS).filter(&:present?)
      Array.from(document.querySelectorAll('thead th')).map((th) => th.textContent.trim())
    JS
  end

  # Opens the column customizer popover.
  def open_column_customizer
    find("[data-controller='mensa-column-customizer'] button.mensa-table__control_bar__button").click
    assert_selector ".mensa-table__column_customizer__popover:not(.hidden)", wait: 3
  end

  # Clicks the visibility toggle for the named column inside an already-open customizer.
  def toggle_column_visibility(column_name)
    within("[data-column-name='#{column_name}']") do
      find(".mensa-table__column_customizer__visibility").click
    end
  end

  # Opens the views dropdown and waits for it to become visible.
  def open_views_dropdown
    return if all(".mensa-table__views__dropdown:not(.hidden)", wait: 0.1).present?

    find(".mensa-table__views__trigger").click
    assert_selector ".mensa-table__views__dropdown:not(.hidden)", wait: 3
  end

  def show_filters
    find("[data-view-id='default'] button[data-action='mensa-views#select']").click
  end

  # Simulates an HTML5 drag-and-drop from +source+ to +target+.
  # Pass above: true to insert source before target; false (default) to insert after.
  def drag_html5(source, target, above: false)
    y_offset = above ? -1 : 1
    execute_script(<<~JS, source.native, target.native, y_offset)
      const src = arguments[0];
      const tgt = arguments[1];
      const yOff = arguments[2];
      const dt = new DataTransfer();

      src.dispatchEvent(new DragEvent('dragstart', {bubbles: true, cancelable: true, dataTransfer: dt}));

      const rect = tgt.getBoundingClientRect();
      tgt.dispatchEvent(new DragEvent('dragover', {
        bubbles: true, cancelable: true,
        clientX: rect.left + rect.width / 2,
        clientY: rect.top + rect.height / 2 + yOff,
        dataTransfer: dt
      }));

      tgt.dispatchEvent(new DragEvent('drop', {bubbles: true, cancelable: true, dataTransfer: dt}));
      src.dispatchEvent(new DragEvent('dragend', {bubbles: true, cancelable: true, dataTransfer: dt}));
    JS
  end
end
