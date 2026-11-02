require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "requires authentication" do
    get search_url(q: "anything")

    assert_redirected_to new_session_path
  end

  test "returns matching notes as a turbo stream" do
    sign_in_as @user
    create_note(title: "Unique maple syrup", body: "From Vermont")

    get search_url(q: "maple"), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match /text\/vnd\.turbo-stream\.html/, response.media_type
    assert_match /turbo-stream/, response.body
    assert_match /Unique maple syrup/, response.body
  end

  test "result rows link into the edit flow" do
    sign_in_as @user
    note = create_note(title: "Unique maple syrup", body: "From Vermont")

    get search_url(q: "maple"), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_match edit_category_note_path(note.category, note), response.body
  end

  test "blank query renders the normal category list instead of results" do
    sign_in_as @user

    get search_url(q: "  "), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match /action="replace" targets="\.categories_list"/, response.body
    # Category accordion is rendered for a blank query, with no "no matches" note.
    assert_match /<details/, response.body
    assert_no_match /No notes match/, response.body
  end

  test "searches are scoped to the signed-in user" do
    sign_in_as @user
    # Give user one a note that shares a keyword with user two's note.
    my_note = create_note(title: "Second user stuff", body: "Private plans")
    other_user_note = users(:two).categories.first.notes.first

    get search_url(q: "Second"), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    # User one's matching note is present; user two's note is not rendered.
    assert_match my_note.title, response.body
    assert_no_match /data-note-id="#{other_user_note.id}"/, response.body
  end

  test "renders html index page for direct visits" do
    sign_in_as @user
    create_note(title: "Unique maple syrup", body: "From Vermont")

    get search_url(q: "maple")

    assert_response :success
    assert_match /Search/, response.body
    assert_match /Unique maple syrup/, response.body
  end

  private

    def create_note(title:, body:)
      category = @user.categories.create!(name: "Seasonal #{SecureRandom.hex(4)}")
      note = category.notes.build(title: title, position: 1)
      note.content = body
      note.save!
      note
    end
end
