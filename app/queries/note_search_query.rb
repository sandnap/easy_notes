# Search a user's notes (across all categories) by title or markdown body.
class NoteSearchQuery
  def initialize(user:, query:)
    @user = user
    @query = query.to_s.strip
  end

  def results
    return Note.none if @query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    Note.joins(:category)
        .where(categories: { user_id: @user.id })
        .where("notes.title LIKE ? ESCAPE '\\' OR notes.content LIKE ? ESCAPE '\\'", pattern, pattern)
        .includes(:category)
        .order(updated_at: :desc)
        .limit(50)
  end
end
