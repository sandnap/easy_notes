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
      # Reorder notes after updating the position
      reorder_notes(@category, @note.position)
      respond_to do |format|
        format.html do
          redirect_to edit_category_note_path(@category, @note),
            notice: "Note was successfully updated."
        end
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def reorder_notes(category, new_position)
    # Get all notes in the category, ordered by position
    notes = category.notes.order(:position)

    # Update positions for all notes after the new position
    notes.each_with_index do |note, index|
      note.update(position: index + 1) if note.position != index + 1
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
