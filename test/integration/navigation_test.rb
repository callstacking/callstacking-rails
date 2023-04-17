require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "HUD is loaded" do
    get '/?debug=1'
    assert_match(/Hello/, @response.body)
    assert_match(/iframe/, @response.body)
    assert_match(/#{Callstacking::Rails::Trace::ICON}/, @response.body)
    assert_match(/#{Callstacking::Rails::Settings::PRODUCTION_URL}\/traces/, @response.body)
  end

  test "HUD is not loaded" do
    get '/'
    assert_match(/Hello/, @response.body)
    assert_no_match(/iframe/, @response.body)
    assert_no_match(/#{Callstacking::Rails::Trace::ICON}/, @response.body)
    assert_no_match(/#{Callstacking::Rails::Settings::PRODUCTION_URL}\/traces/, @response.body)
  end
end
