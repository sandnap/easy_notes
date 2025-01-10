class NotesController < ApplicationController
  before_action :set_category
  before_action :set_categories, only: [ :new, :create, :edit, :update ]
  before_action :set_note, only: [ :edit, :update ]

  def new
    @note = @category.notes.build
  end

  def create
    @note = @category.notes.build(note_params)

    if @note.save
      @note = @category.notes.find(@note.id) # Reload to ensure associations
      redirect_to edit_category_note_path(@category, @note), notice: "Note was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to edit_category_note_path(@category, @note), notice: "Note was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note = @category.notes.find(params[:id])
    @note.destroy

    respond_to do |format|
      format.html { redirect_to root_path, notice: "Note was successfully deleted." }
    end
  end

  private
    def set_category
      @category = Current.user.categories.find(params[:category_id])
    end

    def set_categories
      @categories = Current.user.categories.includes(:notes)
    end

    def set_note
      @note = @category.notes.find(params[:id])
    end

    def note_params
      params.require(:note).permit(:title, :content, :position)
    end
end
