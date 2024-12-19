require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @category = Category.new(
      name: "Test Category",
      user: @user
    )
  end

  test "should be valid" do
    assert @category.valid?
  end

  test "name should be present" do
    @category.name = ""
    assert_not @category.valid?
  end

  test "should belong to a user" do
    @category.user = nil
    assert_not @category.valid?
  end

  test "name should be unique per user" do
    duplicate_category = @category.dup
    @category.save
    assert_not duplicate_category.valid?
  end

  test "should allow same name for different users" do
    other_user = users(:two)
    duplicate_category = Category.new(
      name: @category.name,
      user: other_user
    )
    @category.save
    assert duplicate_category.valid?
  end

  test "should destroy associated notes" do
    @category.save
    @category.notes.create!(title: "Test Note", content: "Test Content")
    assert_difference("Note.count", -1) do
      @category.destroy
    end
  end
end
