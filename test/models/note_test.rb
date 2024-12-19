require "test_helper"

class NoteTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @category = categories(:one)
    @note = Note.new(
      title: "Test Note",
      content: "Test Content",
      category: @category
    )
  end

  test "should be valid" do
    assert @note.valid?
  end

  test "title should be present" do
    @note.title = ""
    assert_not @note.valid?
  end

  test "content should be present" do
    @note.content = ""
    assert_not @note.valid?
  end

  test "should belong to a category" do
    @note.category = nil
    assert_not @note.valid?
  end
end
