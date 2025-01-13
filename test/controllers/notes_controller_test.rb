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

  test "should get edit" do
    get edit_category_note_url(@category, @note), headers: { "Accept" => "text/html, application/xhtml+xml" }
    assert_response :success
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
