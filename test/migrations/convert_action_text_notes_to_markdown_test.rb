require "test_helper"
require Rails.root.join("db/migrate/20261102140000_convert_action_text_notes_to_markdown")

class ConvertActionTextNotesToMarkdownTest < ActiveSupport::TestCase
  test "copies action text html into notes.content and keeps the rich text row" do
    note = notes(:one)
    note.update_column(:content, "stale column")
    ActionText::RichText.create!(
      record_type: "Note",
      record_id: note.id,
      name: "content",
      body: "<div>Hello <strong>there</strong></div>"
    )

    ConvertActionTextNotesToMarkdown.new.up

    assert_equal "Hello **there**", note.reload.content
    assert ActionText::RichText.exists?(record_type: "Note", record_id: note.id, name: "content")
  end

  test "blank rich text keeps existing column text" do
    note = notes(:one)
    note.update_column(:content, "kept plain")
    ActionText::RichText.create!(
      record_type: "Note",
      record_id: note.id,
      name: "content",
      body: "<div><br></div>"
    )

    ConvertActionTextNotesToMarkdown.new.up

    assert_equal "kept plain", note.reload.content
  end
end
