require "application_system_test_case"

class BookmarkableNotesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "selecting a note appends the note id to the URL and survives a page refresh" do
    sign_in_via_ui

    assert_current_path root_path

    # Open the category accordion and click the note in the sidebar
    within("#sidebar") do
      find("details#category_#{@category.id} summary").click
      click_link @note.title
    end

    assert_selector "#main h1", text: @note.title, wait: 5
    assert_current_path bookmark_note_path(@note)

    # Refresh the page (or visit the bookmarked URL directly)
    visit current_path

    assert_current_path bookmark_note_path(@note)
    assert_selector "#main h1", text: @note.title, wait: 5
    assert_selector "input[name='note[title]'][value='#{@note.title}']"
    assert_selector "#sidebar details#category_#{@category.id}[open]"
    assert_selector "#sidebar div.note.bg-shade[data-note-id='#{@note.id}']"

    # Closing the note resets the URL back to root_path
    within("#main") do
      click_link "Close"
    end

    assert_selector "#main h2", text: "Select or create a note to get started", wait: 5
    assert_current_path root_path
  end

  private

    def sign_in_via_ui
      visit new_session_path
      page.execute_script(<<~JS, @user.email_address)
        const form = document.querySelector("#main form")
        form.querySelector("input[name='email_address']").value = arguments[0]
        form.querySelector("input[name='password']").value = "password"
        form.requestSubmit()
      JS
      assert_no_selector "h1", text: "Sign in", wait: 10
      visit root_path
      assert_selector "#sidebar details#category_#{@category.id}", wait: 5
    end
end
