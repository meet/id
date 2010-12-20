require 'test_helper'

class DiscoveryControllerTest < ActionController::TestCase
  
  test "should get identity provider HTML" do
    get :idp
    assert_response :success
    assert_select 'html > body'
  end
  
  test "should get identity provider XRDS" do
    request.accept = 'application/xrds+xml'
    get :idp
    assert_response :success
    assert_select 'XRD > Service > URI'
  end
  
  test "should get identifier HTML" do
    get :user, :username => 'eve'
    assert_response :success
    assert_select 'html > body'
  end
  
  test "should get identifier XRDS" do
    request.accept = 'application/xrds+xml'
    get :user, :username => 'eve'
    assert_response :success
    assert_select 'XRD > Service > URI'
  end
  
end
