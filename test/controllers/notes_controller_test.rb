require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
    sign_in_as @user
  end

  test "should get new" do
    get new_category_note_url(@category), headers: { "Accept" => "text/html, application/xhtml+xml" }
    assert_response :success
  end

  test "should create note" do
    assert_difference("Note.count") do
      post category_notes_url(@category), params: {
        note: {
          title: "New Test Note",
          content: "New Test Content",
          position: 1
        }
      }
    end

    assert_response :redirect
    assert_redirected_to edit_category_note_url(@category, Note.last)
  end

  test "should create note with turbo stream" do
    assert_difference("Note.count") do
      post category_notes_url(@category), params: {
        note: {
          title: "New Test Note",
          content: "New Test Content",
          position: 1
        }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match /turbo-stream/, @response.media_type
  end

  test "renders a sanitized markdown preview" do
    post preview_note_url, params: { content: "**bold** and ~~gone~~" }

    assert_response :success
    assert_match %r{<strong>bold</strong>}, response.body
    assert_match %r{<del>gone</del>}, response.body
  end

  test "preview strips unsafe html" do
    post preview_note_url, params: { content: "<script>alert(1)</script>\n\n[click](javascript:alert(1))" }

    assert_response :success
    assert_no_match(/<script/i, response.body)
    assert_no_match(/javascript:/i, response.body)
  end

  test "preview requires authentication" do
    delete session_url
    post preview_note_url, params: { content: "**bold**" }

    assert_redirected_to new_session_path
  end

  test "should get edit" do
    get edit_category_note_url(@category, @note), headers: { "Accept" => "text/html, application/xhtml+xml" }
    assert_response :success
  end

  test "should get bookmark_note url and scope to current user" do
    get bookmark_note_url(@note), headers: { "Accept" => "text/html, application/xhtml+xml" }
    assert_response :success
    assert_match @note.title, response.body

    other_user_note = notes(:two)
    get bookmark_note_url(other_user_note), headers: { "Accept" => "text/html, application/xhtml+xml" }
    assert_response :not_found
  end

  test "should update note with html" do
    patch category_note_url(@category, @note), params: {
      note: {
        title: "Updated Title",
        content: "Updated Content",
        position: 1
      }
    }, headers: { "Accept" => "text/html" }

    assert_response :redirect
    assert_redirected_to edit_category_note_url(@category, @note)
    @note.reload
    assert_equal "Updated Title", @note.title
  end

  test "should handle failed update with html" do
    patch category_note_url(@category, @note), params: {
      note: {
        title: "", # Invalid title
        content: "Updated Content",
        position: 1
      }
    }, headers: { "Accept" => "text/html" }

    assert_response :unprocessable_entity
  end

  test "should update note with turbo stream" do
    patch category_note_url(@category, @note), params: {
      note: {
        title: "Updated Title",
        content: "Updated Content",
        position: 1
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match /turbo-stream/, @response.media_type
    @note.reload
    assert_equal "Updated Title", @note.title
  end

  test "should handle failed update with turbo stream" do
    patch category_note_url(@category, @note), params: {
      note: {
        title: "", # Invalid title
        content: "Updated Content",
        position: 1
      }
    }, headers: { "Accept" => "text/html" }

    assert_response :unprocessable_entity
  end
end
