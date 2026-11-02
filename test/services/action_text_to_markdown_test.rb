require "test_helper"

class ActionTextToMarkdownTest < ActiveSupport::TestCase
  test "converts paragraphs, emphasis, links, lists, quotes, and code" do
    html = <<~HTML
      <div>Hello <strong>world</strong></div>
      <div><em>slant</em> and <del>old</del></div>
      <div><a href="https://example.com">Example</a></div>
      <h1>Title</h1>
      <ul><li>one</li><li>two</li></ul>
      <ol><li>first</li></ol>
      <blockquote>quoted</blockquote>
      <pre>puts "hi"</pre>
    HTML

    markdown = ActionTextToMarkdown.convert(html)

    assert_includes markdown, "Hello **world**"
    assert_includes markdown, "*slant* and ~~old~~"
    assert_includes markdown, "[Example](https://example.com)"
    assert_includes markdown, "# Title"
    assert_includes markdown, "- one\n- two"
    assert_includes markdown, "1. first"
    assert_includes markdown, "> quoted"
    assert_includes markdown, "```\nputs \"hi\"\n```"
  end

  test "keeps line breaks for lists wrapped in the action text layout" do
    html = <<~HTML
      <div class="trix-content">
        <!-- BEGIN app/views/layouts/action_text/contents/_content.html.erb -->
        <ul><li>one</li><li>two<ul><li>nested</li></ul></li></ul>
      </div>
    HTML

    assert_equal "- one\n- two\n  - nested", ActionTextToMarkdown.convert(html)
  end

  test "keeps a break between separate paragraphs" do
    assert_equal "one\n\ntwo", ActionTextToMarkdown.convert("<div>one</div><div>two</div>")
  end

  test "converts an image attachment to a markdown image" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("png"),
      filename: "pic.png",
      content_type: "image/png"
    )
    html = %(<action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png" filename="pic.png"></action-text-attachment>)

    markdown = ActionTextToMarkdown.convert(html, note_id: 1)

    assert_match %r{!\[pic\.png\]\(/rails/active_storage/blobs/redirect/#{Regexp.escape(blob.signed_id)}/pic\.png\)}, markdown
  end

  test "converts a non-image attachment to a markdown link" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("pdf"),
      filename: "notes.pdf",
      content_type: "application/pdf"
    )
    html = %(<action-text-attachment sgid="#{blob.attachable_sgid}" content-type="application/pdf" filename="notes.pdf"></action-text-attachment>)

    markdown = ActionTextToMarkdown.convert(html, note_id: 1)

    assert_match %r{\[notes\.pdf\]\(/rails/active_storage/blobs/redirect/}, markdown
    assert_no_match(/!\[/, markdown)
  end

  test "missing attachments become plain filenames" do
    html = %(<action-text-attachment sgid="not-a-real-sgid" filename="gone.png"></action-text-attachment>)

    assert_equal "gone.png", ActionTextToMarkdown.convert(html, note_id: 42)
  end
end
