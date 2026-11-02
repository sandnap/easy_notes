require "application_system_test_case"

class MarkdownPreviewTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "toggles between the markdown editor and a view-only preview" do
    visit new_session_path
    page.execute_script(<<~JS, @user.email_address)
      const form = document.querySelector("#main form")
      form.querySelector("input[name='email_address']").value = arguments[0]
      form.querySelector("input[name='password']").value = "password"
      form.requestSubmit()
    JS
    assert_no_selector "h1", text: "Sign in", wait: 10
    visit edit_category_note_path(@category, @note)
    assert_selector "[data-vim-editor-target='input']", wait: 10

    page.execute_script(<<~JS)
      document.querySelector("[data-vim-editor-target='input']").value = "**bold** word"
    JS

    find("[data-markdown-preview-target='previewButton']").click

    assert_selector ".markdown-body strong", text: "bold", wait: 5
    assert_selector "[data-vim-suspended]"
    assert_no_selector "[data-vim-editor-target='input']", visible: true

    find("[data-markdown-preview-target='editButton']").click

    assert_selector "[data-vim-editor-target='input']", visible: true
    assert_no_selector "[data-vim-suspended]"
  end
end
