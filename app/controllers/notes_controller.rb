class NotesController < ApplicationController
  before_action :set_category
  before_action :set_categories, only: [ :new, :create, :edit, :update ]
  before_action :set_note, only: [ :edit, :update, :sort ]

  def new
    @note = @category.notes.build
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("note-form", partial: "form", locals: { note: @note })
        ]
      end
      format.html { render :new }
    end
  end

  def create
    @note = @category.notes.build(note_params)

    if @note.save
      @note = @category.notes.find(@note.id) # Reload to ensure associations
      respond_to do |format|
        flash[:notice] = "Note was successfully created."
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append_all("#category_#{@category.id} .notes_list", partial: "categories/note", locals: { note: @note, category: @category }),
            turbo_stream.replace("note-form", partial: "form", locals: { note: @note }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { redirect_to edit_category_note_path(@category, @note), notice: "Note was successfully created." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash[:alert] = "Note could not be created."
          render turbo_stream: [
            turbo_stream.replace("note-form", partial: "form", locals: { note: @note }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @the_note = @note
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("note-form", partial: "form", locals: { note: @note }, action: "advance")
        ]
      end
      format.html { render :edit }
    end
  end

  def update
    if @note.update(note_params)
      respond_to do |format|
        flash[:notice] = "Note was successfully updated."
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("note-form", partial: "form", locals: { note: @note }),
            turbo_stream.replace_all("[data-note-id='#{@note.id}']", partial: "categories/note", locals: { note: @note, category: @category }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { redirect_to edit_category_note_path(@category, @note), notice: "Note was successfully updated." }
      end
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

  def destroy
    @note = @category.notes.find(params[:id])
    @note.destroy

    respond_to do |format|
      format.turbo_stream do
        flash[:notice] = "Note was successfully deleted."
        puts "destroy"
        render turbo_stream: [
          turbo_stream.remove_all("[data-note-id='#{@note.id}']"),
          turbo_stream.update("flash", partial: "shared/flash"),
          turbo_stream.replace("note-form", partial: "home/select_note")
        ]
      end
      format.html { redirect_to root_path, notice: "Note was successfully deleted." }
    end
  end

  private

  def reorder_notes(category, new_position, updated_note_id)
    # Get all notes in the category, ordered by position
    notes = category.notes.order(:position)
    puts "***********************************"
    puts "New position: #{new_position}"
    puts "Updated note id: #{updated_note_id}"
    puts "Notes: #{notes.map { |note| note.title + " - #{note.position}" }}"
    puts "***********************************"
    notes.each_with_index do |note, index|
      if index > new_position && note.id != updated_note_id
        note.update(position: index + 1)
      end
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
