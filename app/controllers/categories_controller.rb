class CategoriesController < ApplicationController
  before_action :set_categories, only: [ :index, :update, :destroy ]

  def index
  end

  def create
    @category = Current.user.categories.build(category_params)

    if @category.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # The mobile and laptop sidebar
            turbo_stream.prepend_all(".categories_list", partial: "categories/category",  locals: { category: @category }),
            # The edit form
            turbo_stream.prepend("categories_edit_list", partial: "categories/category_row",  locals: { category: @category }),
            turbo_stream.replace_all(".dialog", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Category was successfully created." })
          ]
        end
        format.html { redirect_to root_path, notice: "Category was successfully created." }
      end
    else
      render turbo_stream: turbo_stream.update("dialog",
        partial: "shared/category_form",
        locals: { category: @category }
      ), status: :unprocessable_entity
    end
  end

  def update
    @category = Current.user.categories.find(params[:id])

    if @category.update(category_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # The mobile and laptop sidebar
            turbo_stream.replace_all(".category_#{@category.id}", partial: "categories/category",  locals: { category: @category }),
            # The edit form
            turbo_stream.replace("edit_category_#{@category.id}", partial: "categories/category_row",  locals: { category: @category }),
            turbo_stream.replace_all(".dialog", ""),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Category was successfully updated." })
          ]
        end
        format.html { redirect_to categories_path, notice: "Category was successfully updated." }
      end
    else
      render turbo_stream: turbo_stream.update("dialog",
        partial: "shared/category_form",
        locals: { category: @category }
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @category = Current.user.categories.find(params[:id])
    @category.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          # The mobile and laptop sidebar
          turbo_stream.remove_all(".category_#{@category.id}"),
          # The edit form
          turbo_stream.remove("edit_category_#{@category.id}"),
          turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Category and all its notes were successfully deleted." })
        ]
      end
      format.html { redirect_to categories_path, notice: "Category and all its notes were successfully deleted." }
    end
  end

  private

  def set_categories
    @categories = Current.user.categories
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
