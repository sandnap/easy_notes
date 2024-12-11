class HomeController < ApplicationController
  def index
    @categories = Current.user.categories.includes(:notes)
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.debug "Turbo stream request received"
        render turbo_stream: [
          turbo_stream.update("main", partial: "home/select_note")
        ]
      end
      Rails.logger.debug "format.html"
      format.html { render :index }
    end
  end
end
