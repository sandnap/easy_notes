# Converts Trix / Action Text HTML into Markdown.
# Attachments become Active Storage links. A missing blob becomes its filename.
class ActionTextToMarkdown
  def self.convert(html, note_id: nil)
    new(html, note_id: note_id).convert
  end

  def initialize(html, note_id: nil)
    @html = html.to_s
    @note_id = note_id
  end

  def convert
    fragment = Nokogiri::HTML5.fragment(@html)
    blocks = []
    fragment.children.each do |node|
      next if ignorable?(node)

      rendered = render_block(node)
      blocks << rendered.to_s.strip
    end
    blocks.join("\n\n").gsub(/\n{3,}/, "\n\n").strip
  end

  private

    def ignorable?(node)
      return true if node.comment?

      node.text? && node.text.strip.empty?
    end

    def render_block(node)
      return escape_text(node.text) if node.text?

      case node.name
      when "div"
        render_div(node)
      when "p"
        render_inline(node)
      when /\Ah[1-6]\z/
        "#{"#" * node.name[1].to_i} #{render_inline(node).strip}"
      when "blockquote"
        render_blockquote(node)
      when "pre"
        render_code_block(node)
      when "ul"
        render_list(node, ordered: false)
      when "ol"
        render_list(node, ordered: true)
      when "action-text-attachment"
        render_attachment(node)
      else
        render_inline(node)
      end
    end

    def render_div(node)
      blocks = node.element_children.select { |child| block_element?(child) }
      if blocks.any? && !meaningful_inline?(node)
        return blocks.map { |child| render_block(child).to_s.strip }.reject(&:empty?).join("\n\n")
      end

      render_inline(node)
    end

    def block_element?(node)
      node.name.match?(/\Ah[1-6]\z/) || %w[div p blockquote pre ul ol action-text-attachment].include?(node.name)
    end

    def meaningful_inline?(node)
      node.children.any? do |child|
        next false if child.comment?
        next false if child.element? && block_element?(child)
        next false if child.text? && child.text.strip.empty?

        true
      end
    end

    def render_blockquote(node)
      inner = if node.element_children.any? { |child| block_element?(child) }
        node.element_children.map { |child| render_block(child).to_s.strip }.reject(&:empty?).join("\n\n")
      else
        render_inline(node).strip
      end
      inner.lines.map { |line| "> #{line.chomp}" }.join("\n")
    end

    def render_code_block(node)
      code = node.text.chomp
      "```\n#{code}\n```"
    end

    def render_list(node, ordered:)
      items = node.element_children.select { |child| child.name == "li" }
      items.each_with_index.map { |item, index|
        marker = ordered ? "#{index + 1}. " : "- "
        render_list_item(item, marker)
      }.join("\n")
    end

    def render_list_item(item, marker)
      inline = []
      nested = []
      item.children.each do |child|
        if child.element? && %w[ul ol].include?(child.name)
          nested << render_list(child, ordered: child.name == "ol")
        else
          inline << render_inline_node(child)
        end
      end
      text = "#{marker}#{inline.join.strip}"
      return text if nested.empty?

      indented = nested.join("\n").lines.map { |line| "  #{line}" }.join
      "#{text}\n#{indented.chomp}"
    end

    def render_inline(node)
      node.children.reject { |child| child.comment? }.map { |child| render_inline_node(child) }.join
    end

    def render_inline_node(node)
      return escape_text(node.text) if node.text?

      case node.name
      when "strong", "b"
        "**#{render_inline(node)}**"
      when "em", "i"
        "*#{render_inline(node)}*"
      when "del", "s", "strike"
        "~~#{render_inline(node)}~~"
      when "a"
        "[#{render_inline(node)}](#{node["href"]})"
      when "br"
        "\n"
      when "code"
        "`#{node.text}`"
      when "action-text-attachment"
        render_attachment(node)
      else
        render_inline(node)
      end
    end

    def render_attachment(node)
      filename = node["filename"].presence || "attachment"
      attachable = resolve_attachable(node["sgid"])
      if attachable.nil?
        Rails.logger.warn("Note #{@note_id}: missing attachment #{filename}")
        return escape_text(filename)
      end

      url = Rails.application.routes.url_helpers.rails_blob_path(attachable, only_path: true)
      label = filename.to_s.gsub(/[\[\]]/) { |char| "\\#{char}" }
      if image_attachable?(attachable, node)
        "![#{label}](#{url})"
      else
        "[#{label}](#{url})"
      end
    end

    def resolve_attachable(sgid)
      return nil if sgid.blank?

      ActionText::Attachable.from_attachable_sgid(sgid)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      nil
    end

    def image_attachable?(attachable, node)
      type = if attachable.respond_to?(:content_type)
        attachable.content_type
      else
        node["content-type"]
      end
      type.to_s.start_with?("image/")
    end

    def escape_text(text)
      text.to_s.gsub(/[\\`*_\[]/) { |char| "\\#{char}" }
    end
end
