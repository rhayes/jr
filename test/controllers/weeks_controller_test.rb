require 'test_helper'

class WeeksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get weeks_index_url
    assert_response :success
  end

  test "should get show" do
    get weeks_show_url
    assert_response :success
  end

  test "should get edit" do
    get weeks_edit_url
    assert_response :success
  end

  test "should get create" do
    get weeks_create_url
    assert_response :success
  end

  test "should get update" do
    get weeks_update_url
    assert_response :success
  end

end
