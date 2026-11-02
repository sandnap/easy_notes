require "test_helper"

class NoteSearchQueryTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "matches note title" do
    note = create_note(user: @user, title: "Grocery list", body: "Buy milk")

    results = NoteSearchQuery.new(user: @user, query: "Grocery").results

    assert_includes results, note
  end

  test "matches note content" do
    note = create_note(user: @user, title: "Shopping", body: "Remember the avocados")

    results = NoteSearchQuery.new(user: @user, query: "avocado").results

    assert_includes results, note
  end

  test "is case-insensitive" do
    note = create_note(user: @user, title: "Markdown Cheatsheet", body: "Some body")

    results = NoteSearchQuery.new(user: @user, query: "markdown").results

    assert_includes results, note
  end

  test "is scoped to the user's notes only" do
    mine = create_note(user: @user, title: "Private idea", body: "Secret plans")
    other = create_note(user: users(:two), title: "Private idea", body: "Something else")

    results = NoteSearchQuery.new(user: @user, query: "Private").results

    assert_includes results, mine
    assert_not_includes results, other
  end

  test "returns empty for a blank query" do
    assert_empty NoteSearchQuery.new(user: @user, query: "  ").results
  end

  test "does not treat SQL wildcards as wildcards" do
    literal = create_note(user: @user, title: "100% committed", body: "body")
    create_note(user: @user, title: "Percent", body: "100 percent")
    create_note(user: @user, title: "Anything", body: "100x more")

    results = NoteSearchQuery.new(user: @user, query: "100%").results

    assert_includes results, literal
    assert_equal 1, results.length
  end

  test "orders by most recently updated first" do
    older = create_note(user: @user, title: "Alpha match", body: "body")
    newer = create_note(user: @user, title: "Beta match", body: "body")
    older.touch(time: 2.days.ago)
    newer.touch(time: 1.day.ago)

    assert_equal [ newer, older ], NoteSearchQuery.new(user: @user, query: "match").results.to_a
  end

  private

    def create_note(user:, title:, body:)
      category = user.categories.create!(name: "Cat #{SecureRandom.hex(4)}")
      note = category.notes.build(title: title, position: 1)
      note.content = body
      note.save!
      note
    end
end
