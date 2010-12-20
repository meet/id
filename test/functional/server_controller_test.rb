require 'test_helper'
require 'mock_directory'

class ServerControllerTest < ActionController::TestCase
  
  include Rack::Utils
  
  def setup
    Directory.mock_user('eve', [ 'foo' ])
    @eve_id = "http://#{request.host}/eve"
    
    Directory.mock_user('bob', [ 'one', 'two' ])
    @bob_id = "http://#{request.host}/bob"
  end
  
  def teardown
    Directory.empty
  end
  
  LOCALHOST = 'http://localhost:8001/return'
  CHECKID = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => LOCALHOST
  }
  
  test "should require login" do
    post :openid, CHECKID
    assert_redirected_to login_url(CHECKID)
  end
  
  test "should allow via session" do
    Directory.mock_app(LOCALHOST)
    request.session[:username] = 'eve'
    post :openid, CHECKID
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_match @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny via session" do
    Directory.mock_app('http://other.host/')
    request.session[:username] = 'eve'
    post :openid, CHECKID
    assert_response :success
    assert_template :unknown_site
  end
  
  test "should allow via login" do
    Directory.mock_app(LOCALHOST)
    request.env['REMOTE_USER'] = 'eve'
    get :login, CHECKID
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_match @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny via login" do
    Directory.mock_app('http://other.host/')
    request.env['REMOTE_USER'] = 'eve'
    get :login, CHECKID
    assert_response :success
    assert_template :unknown_site
  end
  
  test "should allow correct identity" do
    Directory.mock_app(LOCALHOST)
    request.env['REMOTE_USER'] = 'eve'
    get :login, CHECKID.merge({ 'openid.identity' => @eve_id, 'openid.claimed_id' => @eve_id })
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_match @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny wrong identity" do
    Directory.mock_app(LOCALHOST)
    id = "http://#{request.host}/alice"
    request.env['REMOTE_USER'] = 'eve'
    get :login, CHECKID.merge({ 'openid.identity' => id, 'openid.claimed_id' => id })
    assert_response :success
    assert_template :wrong_identity
  end
  
  GROUPS = 'http://id.meet.mit.edu/schema/groups'
  CHECKID_AND_GROUPS = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => LOCALHOST,
    'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
    'openid.ax.mode' => 'fetch_request',
    'openid.ax.type.groups' => GROUPS,
    'openid.ax.required' => 'groups'
  }
  
  test "should allow with groups via login" do
    Directory.mock_app(LOCALHOST)
    request.env['REMOTE_USER'] = 'bob'
    get :login, CHECKID_AND_GROUPS
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_match @bob_id, params['openid.identity']
    assert_match GROUPS, params['openid.ax.type.ext0']
    assert_match 'one', params['openid.ax.value.ext0.1']
    assert_match 'two', params['openid.ax.value.ext0.2']
  end
  
end
