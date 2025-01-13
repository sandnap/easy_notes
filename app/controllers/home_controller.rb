class HomeController < ApplicationController
  def index
    @the_note = nil
    @categories = Current.user.categories.includes(:notes).order("notes.position ASC")
  end
end
