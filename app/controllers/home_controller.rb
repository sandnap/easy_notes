class HomeController < ApplicationController
  def index
    @categories = Current.user.categories.includes(:notes).order("notes.position ASC")
  end
end
