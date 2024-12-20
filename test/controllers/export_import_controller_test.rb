require "test_helper"

class ExportImportControllerTest < ActionDispatch::IntegrationTest
  test "should get export" do
    get export_import_export_url
    assert_response :success
  end

  test "should get import" do
    get export_import_import_url
    assert_response :success
  end
end
