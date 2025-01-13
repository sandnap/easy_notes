class HomeController < ApplicationController
  def index
    @the_note = nil
    @categories = Current.user.categories.includes(:notes).order("notes.position ASC")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("note-form", partial: "select_note")
        ]
      end
      format.html { render :index }
    end
  end
end
