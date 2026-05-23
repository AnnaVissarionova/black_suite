require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get profiles_show_url
    assert_response :success
  end

  test "should get update_token" do
    get profiles_update_token_url
    assert_response :success
  end
end
