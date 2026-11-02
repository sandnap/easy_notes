require_relative "20261102140000_convert_action_text_notes_to_markdown"

class ReconvertActionTextNotesPreservingBreaks < ActiveRecord::Migration[8.0]
  def up
    ConvertActionTextNotesToMarkdown.new.up
  end

  def down
    # Rich text rows are left in place. Markdown already written to notes.content stays.
  end
end
