class HomeController < ApplicationController
  def index
    @categories = Current.user.categories.includes(:notes)
  end
end
