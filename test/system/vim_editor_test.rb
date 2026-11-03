require "application_system_test_case"

class VimEditorTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
  end

  test "Vim mode starts enabled in NORMAL mode on initial load and can be toggled off and on" do
    sign_in_and_open_note

    assert_selector "[data-vim-editor-target='toggleButton']", text: "Vim: On"
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    assert_selector ".vim-block-cursor"
    assert_equal "rgba(0, 0, 0, 0)", page.evaluate_script("getComputedStyle(document.querySelector('[data-vim-editor-target=input]')).caretColor")

    # Even if the editor is blurred (focus on document.body), pressing Normal-mode keys works immediately
    set_editor_text("hello world")
    page.execute_script("document.activeElement?.blur()")
    initial_left = page.evaluate_script("document.querySelector('.vim-block-cursor').getBoundingClientRect().left")
    page.execute_script(<<~JS)
      document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "w", bubbles: true, cancelable: true }))
    JS
    assert_equal 6, editor_cursor_offset
    moved_left = page.evaluate_script("document.querySelector('.vim-block-cursor').getBoundingClientRect().left")
    assert_operator moved_left, :>, initial_left

    press_vim_keys("i")
    assert_selector "[data-vim-editor-target='badge']", text: "INSERT"
    assert_no_selector ".vim-block-cursor"

    press_vim_keys("Escape")
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    assert_selector ".vim-block-cursor"

    # Clicking toggle turns Vim mode off
    page.execute_script("document.querySelector(\"[data-vim-editor-target='toggleButton']\").click()")
    assert_selector "[data-vim-editor-target='toggleButton']", text: "Vim: Off"
    assert_selector "[data-vim-editor-target='badge']", visible: :hidden
    assert_no_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    assert_no_selector ".vim-block-cursor"
  end

  test "normal mode navigation and character/word deletion (h, l, w, b, 0, $, x, dw)" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("alpha beta gamma")

    # Move to start of line (0), forward a word (w -> 'beta'), right one char (l -> 'e'), delete char (x)
    press_vim_keys("0", "w", "l", "x")
    assert_equal "alpha bta gamma", editor_text

    # Move back to start of word (b -> 'bta') and delete word (dw)
    press_vim_keys("b", "d", "w")
    assert_equal "alpha gamma", editor_text

    # $ moves to the true end of the line (after the last character)
    press_vim_keys("$")
    assert_equal 11, editor_cursor_offset

    # 0 moves to start, and l repeated reaches the true end of the line (11)
    press_vim_keys("0", *Array.new(11, "l"))
    assert_equal 11, editor_cursor_offset
  end

  test "line number jump with <line>G and bare G" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("First line\nSecond line\nThird line\nFourth line")

    # 2G jumps to the start of line 2 ("Second line", offset 11)
    press_vim_keys("2", "G")
    assert_equal 11, editor_cursor_offset

    # 3G jumps to the start of line 3 ("Third line", offset 23)
    press_vim_keys("3", "G")
    assert_equal 23, editor_cursor_offset

    # Bare G jumps to the start of the last line ("Fourth line", offset 34)
    press_vim_keys("G")
    assert_equal 34, editor_cursor_offset

    # 1G jumps back to line 1 (offset 0)
    press_vim_keys("1", "G")
    assert_equal 0, editor_cursor_offset
  end

  test "line deletion (dd), yank/paste (yy, p, P), and undo (u)" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("Line one\nLine two\nLine three")

    # Go to first line (gg), delete line (dd) -> "Line one" is removed and yanked
    press_vim_keys("g", "g", "d", "d")
    assert_equal "Line two\nLine three", editor_text

    # Paste below current line ("Line two") with 'p'
    press_vim_keys("p")
    assert_equal "Line two\nLine one\nLine three", editor_text

    # Yank current line ("Line one") with 'yy' and paste above with 'P'
    press_vim_keys("y", "y", "P")
    assert_equal "Line two\nLine one\nLine one\nLine three", editor_text

    # Undo last paste with 'u'
    press_vim_keys("u")
    assert_equal "Line two\nLine one\nLine three", editor_text
  end

  test "vertical motions scroll the note and keep the cursor inside it" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text((1..120).map { |number| "Line #{number}" }.join("\n"))
    page.execute_script(<<~JS)
      const editor = document.querySelector("[data-vim-editor-target='input']")
      const main = document.querySelector("#main")
      editor.scrollTop = 0
      editor.setSelectionRange(0, 0)
      main.scrollTop = 0
    JS

    before = editor_scroll_metrics
    press_vim_keys(*Array.new(100, "j"))
    below = editor_scroll_metrics

    assert below["inside"], "cursor left the editor while moving down: #{below}"
    assert_operator below["editorScroll"], :>, before["editorScroll"]
    assert_equal before["mainScroll"], below["mainScroll"]
    assert_equal before["windowScroll"], below["windowScroll"]

    press_vim_keys(*Array.new(100, "k"))
    above = editor_scroll_metrics

    assert above["inside"], "cursor left the editor while moving up: #{above}"
    assert_operator above["editorScroll"], :<, below["editorScroll"]
    assert_equal before["mainScroll"], above["mainScroll"]
    assert_equal before["windowScroll"], above["windowScroll"]
  end

  test "f finds a character and v f selects through it" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("hello")
    press_vim_keys("f")
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL (f)"
    press_vim_keys("l")
    assert_equal 2, editor_cursor_offset

    press_vim_keys("0", "2", "f", "l")
    assert_equal 3, editor_cursor_offset

    press_vim_keys("0", "f", "z")
    assert_equal 0, editor_cursor_offset

    set_editor_text("ab\ncd")
    press_vim_keys("f", "c")
    assert_equal 0, editor_cursor_offset

    set_editor_text("hello")
    press_vim_keys("v", "f")
    assert_selector "[data-vim-editor-target='badge']", text: "VISUAL (f)"
    press_vim_keys("l")
    assert_equal [0, 3], editor_selection
    press_vim_keys("d")
    assert_equal "lo", editor_text
  end

  test "visual selection deletes with d and pastes with p and P" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("hello")
    press_vim_keys("v", "l")
    assert_equal [0, 2], editor_selection
    press_vim_keys("d")
    assert_equal "llo", editor_text
    press_vim_keys("P")
    assert_equal "hello", editor_text

    set_editor_text("hello world")
    press_vim_keys("v", "$", "d")
    assert_equal "", editor_text

    set_editor_text("alpha beta gamma")
    press_vim_keys("v", "2", "e")
    assert_equal [0, 10], editor_selection
    press_vim_keys("d")
    assert_equal " gamma", editor_text

    set_editor_text("Line one\nLine two\nLine three")
    press_vim_keys("V")
    assert_selector "[data-vim-editor-target='badge']", text: "VISUAL LINE"
    press_vim_keys("j")
    assert_equal [0, 18], editor_selection
    press_vim_keys("d")
    assert_equal "Line three", editor_text
    press_vim_keys("p")
    assert_equal "Line three\nLine one\nLine two", editor_text

    set_editor_text("hello")
    press_vim_keys("v", "l")
    assert_selector "[data-vim-editor-target='badge']", text: "VISUAL"
    assert_no_selector ".vim-block-cursor"
    press_vim_keys("Escape")
    assert_equal "hello", editor_text
    assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    assert_equal [1, 1], editor_selection
    assert_selector ".vim-block-cursor"
  end

  test "ex-command :w saves the note in Normal mode" do
    sign_in_and_open_note
    enable_vim_mode

    set_editor_text("Saved via :w command")

    press_vim_keys(":", "w")
    assert_selector "[data-vim-editor-target='badge']", text: ":w"

    press_vim_keys("Enter")
    assert_text "Note was successfully updated.", wait: 5
    assert_equal "Saved via :w command", @note.reload.content
  end

  private

    def press_vim_keys(*keys)
      page.execute_script(<<~JS, keys)
        const editor = document.querySelector("[data-vim-editor-target='input']")
        editor.focus()
        for (const key of arguments[0]) {
          editor.dispatchEvent(new KeyboardEvent("keydown", {
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
      assert_selector "[data-controller~='vim-editor'][data-vim-ready='true'] [data-vim-editor-target='input']", wait: 10
    end

    def enable_vim_mode
      page.execute_script(<<~JS)
        const btn = document.querySelector("[data-vim-editor-target='toggleButton']")
        if (btn && btn.textContent.trim() === "Vim: Off") btn.click()
      JS
      assert_selector "[data-vim-editor-target='badge']", text: "NORMAL"
    end

    def set_editor_text(text)
      page.execute_script(<<~JS, text)
        const editor = document.querySelector("[data-vim-editor-target='input']")
        editor.focus()
        editor.value = arguments[0]
        editor.setSelectionRange(0, 0)
      JS
    end

    def editor_text
      page.evaluate_script(<<~JS)
        document.querySelector("[data-vim-editor-target='input']").value
      JS
    end

    def editor_cursor_offset
      page.evaluate_script(<<~JS)
        document.querySelector("[data-vim-editor-target='input']").selectionStart
      JS
    end

    def editor_scroll_metrics
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        requestAnimationFrame(() => requestAnimationFrame(() => {
          const editor = document.querySelector("[data-vim-editor-target='input']")
          const cursor = document.querySelector(".vim-block-cursor")
          const editorBox = editor.getBoundingClientRect()
          const cursorBox = cursor.getBoundingClientRect()
          const inside = getComputedStyle(cursor).display !== "none" &&
            cursorBox.top >= editorBox.top - 1 &&
            cursorBox.bottom <= editorBox.bottom + 1 &&
            cursorBox.left >= editorBox.left - 1 &&
            cursorBox.right <= editorBox.right + 1
          done({
            inside,
            editorScroll: editor.scrollTop,
            mainScroll: document.querySelector("#main").scrollTop,
            windowScroll: window.scrollY
          })
        }))
      JS
    end

    def editor_selection
      page.evaluate_script(<<~JS)
        (() => {
          const editor = document.querySelector("[data-vim-editor-target='input']")
          return [editor.selectionStart, editor.selectionEnd]
        })()
      JS
    end
end
