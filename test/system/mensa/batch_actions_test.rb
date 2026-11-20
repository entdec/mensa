require "application_system_test_case"

class BatchActionsTest < ApplicationSystemTestCase
  test "archives all matching users with a reason from the dialog" do
    visit users_url
    assert_selector "tbody tr"

    find("th input.mensa-table__select-all").click
    assert_text "20 selected"
    click_button "Select all (#{User.count})"
    assert_text "All #{User.count} selected"

    click_button "Archive"
    within "dialog.mensa-batch-dialog" do
      assert_text "Applies to #{User.count} selected rows"
      click_button "Archive"
      assert_text "Reason can't be blank"

      fill_in "Reason", with: "Left the company"
      click_button "Archive"
    end

    assert_text "#{User.count} users archived"
    assert_no_selector "dialog.mensa-batch-dialog"
    assert_equal ["Left the company"], User.distinct.pluck(:archived_reason)
  end

  test "goes back to selecting only this page" do
    visit users_url
    assert_selector "tbody tr"

    find("th input.mensa-table__select-all").click
    click_button "Select all (#{User.count})"
    assert_text "All #{User.count} selected"

    click_button "Only this page (20)"
    assert_text "20 selected"
    assert_button "Select all (#{User.count})"
  end

  test "confirms an action without a form on all matching rows" do
    visit users_url
    assert_selector "tbody tr"

    find("th input.mensa-table__select-all").click
    click_button "Select all (#{User.count})"

    dismiss_confirm "Confirm all #{User.count} selected rows?" do
      click_button "Confirm"
    end
    assert_text "All #{User.count} selected"
  end

  test "only archives the checked rows" do
    visit users_url
    assert_selector "tbody tr"

    checkboxes = all("td input.mensa-table__select-all")
    checkboxes.first(2).each(&:click)
    assert_text "2 selected"
    assert_no_button "Select all (#{User.count})"

    click_button "Archive"
    within "dialog.mensa-batch-dialog" do
      fill_in "Reason", with: "Duplicate"
      click_button "Archive"
    end

    assert_text "2 users archived"
    assert_equal 2, User.where(archived_reason: "Duplicate").count
  end

  test "closes the dialog without running the action" do
    visit users_url
    assert_selector "tbody tr"

    all("td input.mensa-table__select-all").first.click
    click_button "Archive"
    within "dialog.mensa-batch-dialog" do
      click_button "Cancel"
    end

    assert_no_selector "dialog.mensa-batch-dialog"
    assert_equal 0, User.where.not(archived_reason: nil).count
  end

  test "confirms an action without a form" do
    customer = customers(:ahold)
    visit customer_users_url(customer_id: customer.id)
    assert_selector "tbody tr"

    find("th input.mensa-table__select-all").click
    accept_confirm "Make the selected users guests?" do
      click_button "Make guests"
    end

    assert_selector "tbody tr"
    assert_equal ["guest"], customer.users.reload.map(&:role).uniq
    assert_no_button "Remove"
  end
end
