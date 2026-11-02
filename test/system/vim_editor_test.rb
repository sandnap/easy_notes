require "application_system_test_case"

class VimEditorTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "toggling Vim mode starts in NORMAL mode and switches between NORMAL and INSERT" do
    sign_in_and_open_note

    assert_selector "[data-vim-editor-target='toggleButton']", text: "Vim: Off"
    assert_no_selector "[data-vim-editor-target='badge']", text: "NORMAL"

    enable_vim_mode

    assert_selector "[data-vim-editor-target='toggleButton']", text: "Vim: On"
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"

    press_vim_keys("i")
    assert_selector "[data-vim-editor-target='badge']", text: "INSERT"

    press_vim_keys("Escape")
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
  end

  test "normal mode navigation and character/word deletion (h, l, w, b, 0, $, x, dw)" do
    sign_in_and_open_note
    enable_vim_mode

    set_trix_text("alpha beta gamma")

    # Move to start of line (0), forward a word (w -> 'beta'), right one char (l -> 'e'), delete char (x)
    press_vim_keys("0", "w", "l", "x")
    assert_equal "alpha bta gamma", trix_text

    # Move back to start of word (b -> 'bta') and delete word (dw)
    press_vim_keys("b", "d", "w")
    assert_equal "alpha gamma", trix_text

    # $ moves to the true end of the line (after the last character)
    press_vim_keys("$")
    assert_equal 11, trix_cursor_offset

    # 0 moves to start, and l repeated reaches the true end of the line (11)
    press_vim_keys("0", *Array.new(11, "l"))
    assert_equal 11, trix_cursor_offset
  end

  test "line number jump with <line>G and bare G" do
    sign_in_and_open_note
    enable_vim_mode

    set_trix_text("First line\nSecond line\nThird line\nFourth line")

    # 2G jumps to the start of line 2 ("Second line", offset 11)
    press_vim_keys("2", "G")
    assert_equal 11, trix_cursor_offset

    # 3G jumps to the start of line 3 ("Third line", offset 23)
    press_vim_keys("3", "G")
    assert_equal 23, trix_cursor_offset

    # Bare G jumps to the start of the last line ("Fourth line", offset 34)
    press_vim_keys("G")
    assert_equal 34, trix_cursor_offset

    # 1G jumps back to line 1 (offset 0)
    press_vim_keys("1", "G")
    assert_equal 0, trix_cursor_offset
  end

  test "line deletion (dd), yank/paste (yy, p, P), and undo (u)" do
    sign_in_and_open_note
    enable_vim_mode

    set_trix_text("Line one\nLine two\nLine three")

    # Go to first line (gg), delete line (dd) -> "Line one" is removed and yanked
    press_vim_keys("g", "g", "d", "d")
    assert_equal "Line two\nLine three", trix_text

    # Paste below current line ("Line two") with 'p'
    press_vim_keys("p")
    assert_equal "Line two\nLine one\nLine three", trix_text

    # Yank current line ("Line one") with 'yy' and paste above with 'P'
    press_vim_keys("y", "y", "P")
    assert_equal "Line two\nLine one\nLine one\nLine three", trix_text

    # Undo last paste with 'u'
    press_vim_keys("u")
    assert_equal "Line two\nLine one\nLine three", trix_text
  end

  test "ex-command :w saves the note in Normal mode" do
    sign_in_and_open_note
    enable_vim_mode

    set_trix_text("Saved via :w command")

    press_vim_keys(":", "w")
    assert_selector "[data-vim-editor-target='badge']", text: ":w"

    press_vim_keys("Enter")
    assert_text "Note was successfully updated.", wait: 5
    assert_equal "Saved via :w command", @note.reload.content.to_plain_text.strip
  end

  private

    def press_vim_keys(*keys)
      page.execute_script(<<~JS, keys)
        const trix = document.querySelector("trix-editor")
        trix.focus()
        for (const key of arguments[0]) {
          trix.dispatchEvent(new KeyboardEvent("keydown", {
            key,
            bubbles: true,
            cancelable: true
          }))
        }
      JS
    end

    def sign_in_and_open_note
      visit new_session_path
      page.execute_script("window.localStorage.removeItem('easy_notes.vim_mode')")
      page.execute_script(<<~JS, @user.email_address)
        const form = document.querySelector("#main form")
        form.querySelector("input[name='email_address']").value = arguments[0]
        form.querySelector("input[name='password']").value = "password"
        form.requestSubmit()
      JS
      assert_no_selector "h1", text: "Sign in", wait: 10
      visit edit_category_note_path(@category, @note)
      assert_selector "[data-controller~='vim-editor'][data-vim-ready='true'] trix-editor[trix-id]", wait: 10
    end

    def enable_vim_mode
      page.execute_script("document.querySelector(\"[data-vim-editor-target='toggleButton']\").click()")
      assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    end

    def set_trix_text(text)
      page.execute_script(<<~JS, text)
        const trix = document.querySelector("trix-editor")
        trix.focus()
        trix.editor.loadHTML("")
        trix.editor.insertString(arguments[0])
        trix.editor.setSelectedRange([0, 0])
      JS
    end

    def trix_text
      page.evaluate_script(<<~JS)
        document.querySelector("trix-editor").editor.getDocument().toString().replace(/\\n$/, "")
      JS
    end

    def trix_cursor_offset
      page.evaluate_script(<<~JS)
        document.querySelector("trix-editor").editor.getSelectedRange()[0]
      JS
    end
end
