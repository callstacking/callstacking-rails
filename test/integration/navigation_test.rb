require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "HUD is loaded" do
    get '/'
    assert_match(/Hello/, @response.body)
    assert_match(/#{Callstacking::Rails::Trace::ICON}/, @response.body)
  end
end
