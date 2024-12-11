class CategoriesController < ApplicationController
  def create
    @category = Current.user.categories.build(category_params)

    if @category.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("categories", partial: "categories/category", locals: { category: @category }),
            turbo_stream.replace("dialog", ""),
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

  private

  def category_params
    params.require(:category).permit(:name)
  end
end
