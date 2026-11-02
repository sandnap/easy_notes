require "application_system_test_case"

class NotesSearchTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "typing in the sidebar filters notes to matches" do
    sign_in_via_ui

    type_in_sidebar_search("First")

    assert_selector "#sidebar .categories_list .note a", text: "First Note", wait: 5
    assert_no_selector "#sidebar details#category_#{@category.id}"
  end

  test "clearing the search restores the category list" do
    sign_in_via_ui

    type_in_sidebar_search("First")
    assert_selector "#sidebar .categories_list .note", text: "First Note", wait: 5

    type_in_sidebar_search("")
    assert_selector "#sidebar details#category_#{@category.id}", text: "First Category", wait: 5
  end

  test "empty search shows all categories on first load" do
    sign_in_via_ui

    assert_selector "#sidebar details#category_#{@category.id}"
  end

  private

    def type_in_sidebar_search(query)
      page.execute_script(<<~JS, query)
        const input = document.querySelector("#sidebar input[name='q']")
        input.value = arguments[0]
        input.dispatchEvent(new Event("input", { bubbles: true }))
      JS
    end

    def sign_in_via_ui
      visit new_session_path
      page.execute_script(<<~JS, @user.email_address)
        const form = document.querySelector("#main form")
        form.querySelector("input[name='email_address']").value = arguments[0]
        form.querySelector("input[name='password']").value = "password"
        form.requestSubmit()
      JS
      assert_no_selector "h1", text: "Sign in", wait: 5
      assert_selector "#sidebar details#category_#{@category.id}", wait: 5
      assert_current_path root_path
      assert_selector "#sidebar input[data-notes-search-ready='true']", wait: 5
    end
end
