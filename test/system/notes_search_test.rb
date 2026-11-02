require "application_system_test_case"

class NotesSearchTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "typing in the sidebar filters notes to matches" do
    sign_in_via_ui

    within("#sidebar") do
      fill_in placeholder: "Search notes…", with: "First"
    end

    assert_selector "#sidebar .categories_list .note a", text: "First Note"
    assert_no_selector "#sidebar details#category_#{@category.id}"
  end

  test "clearing the search restores the category list" do
    sign_in_via_ui

    within("#sidebar") do
      fill_in placeholder: "Search notes…", with: "First"
    end
    assert_selector "#sidebar .categories_list .note", text: "First Note"

    within("#sidebar") do
      fill_in placeholder: "Search notes…", with: ""
    end
    assert_selector "#sidebar details#category_#{@category.id}", text: "First Category"
  end

  test "empty search shows all categories on first load" do
    sign_in_via_ui

    assert_selector "#sidebar details#category_#{@category.id}"
  end

  private

    def sign_in_via_ui
      visit new_session_path
      fill_in "email_address", with: @user.email_address
      fill_in "password", with: "password"
      click_on "Sign in"
      assert_no_selector "h1", text: "Sign in", wait: 5
      visit root_path
      assert_selector "#sidebar details#category_#{@category.id}", wait: 5
    end
end
