require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @category = categories(:one)
    sign_in_as @user
  end

  test "should get index via root" do
    get root_url
    assert_response :success
    # Each category is rendered twice, once for the mobile view and once for the desktop view
    assert_select "details#category_#{@category.id}", 2
  end

  test "should create category" do
    assert_difference("Category.count") do
      post categories_url, params: {
        category: {
          name: "New Test Category"
        }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_select "turbo-stream[action='prepend'][targets='.categories_list']"
  end

  test "should show category via root" do
    get root_url
    assert_response :success
    # Each category is rendered twice, once for the mobile view and once for the desktop view
    assert_select "details#category_#{@category.id}", 2
  end


  test "should not access other user's categories" do
    other_category = categories(:two)

    get root_url
    assert_response :success
    # Category does not belong to the current user, so it should not be rendered
    assert_select "details#category_#{other_category.id}", 0
  end
end
