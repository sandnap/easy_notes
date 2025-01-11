class NotesController < ApplicationController
  before_action :set_category
  before_action :set_categories, only: [ :new, :create, :edit, :update ]
  before_action :set_note, only: [ :edit, :update, :sort ]

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
    puts "note_params: #{note_params.inspect}"
    if @note.update(note_params)
      redirect_to edit_category_note_path(@category, @note), notice: "Note was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def sort
    new_position = params[:position].to_i
    parent_id = params[:parent_id].to_i

    # Ensure the note belongs to the correct category
    if @note.category_id == parent_id
      @note.update(position: new_position)
      reorder_notes(@category, new_position, @note.id)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def reorder_notes(category, new_position, updated_note_id)
    # Get all notes in the category, ordered by position
    notes = category.notes.where("position >= ? AND id != ?", new_position, updated_note_id).order(:position)

    # Update positions for all notes after the new position
    notes.each do |note|
      note.update(position: note.position + 1)
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
      @categories = Current.user.categories.includes(:notes).order("notes.position ASC")
    end

    def set_note
      @note = @category.notes.find(params[:id])
    end

    def note_params
      params.require(:note).permit(:title, :content, :position)
    end
end
