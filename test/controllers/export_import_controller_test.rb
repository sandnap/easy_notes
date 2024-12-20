require "test_helper"

class ExportImportControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @category = categories(:one)
    @note = notes(:one)
    sign_in_as @user
  end

  test "should get index" do
    get export_import_url
    assert_response :success
  end

  test "should get export" do
    get export_import_export_url
    assert_response :success

    assert_equal "application/x-yaml", response.content_type
    assert_match /notes_export_.*\.yml/, response.headers["Content-Disposition"]

    # Verify YAML content
    yaml_data = YAML.safe_load(response.body)
    assert_kind_of Array, yaml_data
    assert_equal @user.categories.count, yaml_data.length

    category_data = yaml_data.find { |c| c["name"] == @category.name }
    assert_not_nil category_data
    assert_equal @category.notes.count, category_data["notes"].length
  end

  test "should handle import with valid YAML" do
    # Prepare test data
    import_data = [ {
      "name" => "Imported Category",
      "notes" => [ {
        "title" => "Imported Note",
        "content" => { "body" => "Imported content" }
      } ]
    } ].to_yaml

    # Create temp file with test data
    file = Tempfile.new([ "test_import", ".yml" ])
    file.write(import_data)
    file.rewind

    # Perform import
    assert_difference -> { @user.categories.count } => 1, -> { Note.count } => 1 do
      post export_import_import_url, params: { file: fixture_file_upload(file.path, "application/x-yaml") }
    end

    assert_redirected_to export_import_path
    assert_equal "Notes imported successfully", flash[:notice]

    # Verify imported data
    new_category = @user.categories.find_by(name: "Imported Category")
    assert_not_nil new_category
    assert_equal 1, new_category.notes.count
    assert_equal "Imported Note", new_category.notes.first.title
    assert_includes new_category.notes.first.content.body.to_s, "Imported content"
  end

  test "should not override existing notes during import" do
    original_content = @note.content.body.to_s

    # Prepare test data with existing category and note names
    import_data = [ {
      "name" => @category.name,
      "notes" => [ {
        "title" => @note.title,
        "content" => { "body" => "New content that should not override" }
      } ]
    } ].to_yaml

    file = Tempfile.new([ "test_import", ".yml" ])
    file.write(import_data)
    file.rewind

    # Perform import
    assert_no_difference [ "Category.count", "Note.count" ] do
      post export_import_import_url, params: { file: fixture_file_upload(file.path, "application/x-yaml") }
    end

    assert_redirected_to export_import_path
    assert_equal "Notes imported successfully", flash[:notice]

    # Verify original note content was not changed
    @note.reload
    assert_equal original_content, @note.content.body.to_s
  end

  test "should handle import with missing file" do
    post export_import_import_url
    assert_redirected_to export_import_path
    assert_equal "Please select a file to import", flash[:alert]
  end

  test "should handle import with invalid YAML" do
    file = Tempfile.new([ "test_import", ".yml" ])
    file.write("invalid: yaml: content: - ]")
    file.rewind

    post export_import_import_url, params: { file: fixture_file_upload(file.path, "application/x-yaml") }
    assert_redirected_to export_import_path
    assert_match /Error importing notes:/, flash[:alert]
  end

  test "should add new notes to existing category during import" do
    # Prepare test data with existing category but new note
    import_data = [ {
      "name" => @category.name,
      "notes" => [ {
        "title" => "New Note in Existing Category",
        "content" => { "body" => "New note content" }
      } ]
    } ].to_yaml

    file = Tempfile.new([ "test_import", ".yml" ])
    file.write(import_data)
    file.rewind

    assert_difference -> { @category.notes.count } => 1 do
      post export_import_import_url, params: { file: fixture_file_upload(file.path, "application/x-yaml") }
    end

    assert_redirected_to export_import_path
    assert_equal "Notes imported successfully", flash[:notice]

    new_note = @category.notes.find_by(title: "New Note in Existing Category")
    assert_not_nil new_note
    assert_includes new_note.content.body.to_s, "New note content"
  end
end
