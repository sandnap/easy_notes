require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "sign in page hides the sidebar until the user is authenticated" do
    get new_session_path

    assert_response :success
    assert_select "input[placeholder=?]", "Search notes…", count: 0
    assert_select "button", text: "Add Category", count: 0
    assert_select "a", text: "Edit Categories", count: 0
  end

  test "successful sign in renders the sidebar" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_url
    follow_redirect!

    assert_response :success
    assert_select "input[placeholder=?]", "Search notes…"
    assert_select "button", text: "Add Category"
    assert_select "#categories"
  end

  test "failed sign in keeps the typed email address" do
    post session_url, params: { email_address: @user.email_address, password: "wrong-password" }

    assert_redirected_to new_session_path(email_address: @user.email_address)
    follow_redirect!

    assert_response :success
    assert_select "input[name=?][value=?]", "email_address", @user.email_address
  end
end
