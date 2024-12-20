class ExportImportController < ApplicationController
  before_action :get_categories

  def index
  end

  def export
    yaml_data = @categories.as_json(include: :notes).to_yaml
    filename = "notes_export_#{request.host}_#{Time.current.to_fs(:number)}.yml"
    send_data yaml_data, filename: filename, type: "application/x-yaml", disposition: "attachment", status: :ok
  end

  def import
    if request.post?
      if params[:file].present?
        begin
          yaml_data = YAML.safe_load(params[:file].read)

          ActiveRecord::Base.transaction do
            yaml_data.each do |category_data|
              # Find or create category
              category = Current.user.categories.find_or_initialize_by(name: category_data["name"])
              category.save! if category.new_record?

              # Process notes
              if category_data["notes"].present?
                category_data["notes"].each do |note_data|
                  # Find or initialize note
                  note = category.notes.find_or_initialize_by(title: note_data["title"])

                  # don't override existing notes
                  if note.new_record?
                    note.content = note_data["content"]["body"]
                    note.save!
                  end
                end
              end
            end
          end

          redirect_to export_import_path, notice: "Notes imported successfully"
        rescue StandardError => e
          redirect_to export_import_path, alert: "Error importing notes: #{e.message}"
        end
      else
        redirect_to export_import_path, alert: "Please select a file to import"
      end
    end
  end

  private

  def get_categories
    @categories = Current.user.categories.includes(:notes)
  end
end
