class ConvertActionTextNotesToMarkdown < ActiveRecord::Migration[8.0]
  def up
    ActionText::RichText.where(record_type: "Note", name: "content").find_each do |rich_text|
      note = Note.find_by(id: rich_text.record_id)
      next unless note

      markdown = markdown_for(note, rich_text)
      next if markdown.nil?

      note.update_column(:content, markdown)
    end
  end

  def down
    # Rich text rows are left in place. Markdown already written to notes.content stays.
  end

  private

    def markdown_for(note, rich_text)
      if rich_text_present?(rich_text)
        converted = ActionTextToMarkdown.convert(source_html(rich_text), note_id: note.id)
        converted.presence || note.read_attribute(:content).presence
      else
        note.read_attribute(:content).presence
      end
    end

    def rich_text_present?(rich_text)
      body = rich_text.body
      return false if body.nil?

      body.to_plain_text.strip.present? || source_html(rich_text).include?("action-text-attachment")
    end

    # body.to_s renders the Action Text layout, whose comments make the converter
    # flatten lists and consecutive lines. to_html is the stored fragment.
    def source_html(rich_text)
      body = rich_text.body
      return "" if body.nil?

      html = body.respond_to?(:to_html) ? body.to_html : body
      html.to_s
    end
end
