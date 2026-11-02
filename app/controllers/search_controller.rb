class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @categories = Current.user.categories.includes(:notes).order("notes.position ASC")
    @notes = NoteSearchQuery.new(user: Current.user, query: @query).results

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end
end
