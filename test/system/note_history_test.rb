require "application_system_test_case"

class NoteHistoryTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @first = notes(:one)
    @second = @category.notes.create!(title: "Second History Note", content: "Second history content")
  end

  test "back and forward revisit notes opened in this session" do
    sign_in_via_ui
    visit bookmark_note_path(@first)

    assert_selector "#main h1", text: @first.title, wait: 5
    assert_selector "button[aria-label='Previous note'][disabled]"

    within("#sidebar") do
      click_link @second.title
    end

    assert_selector "#main h1", text: @second.title, wait: 5
    find("button[aria-label='Previous note']").click

    assert_selector "#main h1", text: @first.title, wait: 5
    find("button[aria-label='Next note']").click

    assert_selector "#main h1", text: @second.title, wait: 5
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
      assert_selector "#sidebar details#category_#{@category.id}", wait: 5
      page.execute_script("sessionStorage.removeItem('easy_notes.note_history')")
    end
end
