class NotesController < ApplicationController
  before_action :set_category
  before_action :set_categories, only: [:new, :create]

  def new
    @note = @category.notes.build
  end

  def create
    @note = @category.notes.build(note_params)

    if @note.save
      redirect_to category_note_path(@category, @note), notice: "Note was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_category
      @category = Current.user.categories.find(params[:category_id])
    end

    def set_categories
      @categories = Current.user.categories.includes(:notes)
    end

    def note_params
      params.require(:note).permit(:title, :content)
    end
end
