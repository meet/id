require 'test_helper'

class ApplicationFlowsTest < ActionController::IntegrationTest
  
  def setup
    Directory.connect_with(:port => 3389)
  end
  
  CHECKID = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => 'http://localhost:8001/return',
    'openid.realm' => 'http://localhost:8001/'
  }
  
  test "discover and authenticate via login" do
    url = nil
    
    get '/'
    assert_select 'html > head > meta' do |elts|
      url = elts.find { |elt| elt['http-equiv'] == 'X-XRDS-Location' } ['content']
    end
    assert_equal idp_xrds_url, url
    
    get url
    assert_select 'XRD > Service > URI' do |elts|
      url = elts[0].children[0].content
    end
    assert_equal openid_url, url
    
    post url, CHECKID
    assert_redirected_to login_url(CHECKID)
    
    get response.location, {}, { 'REMOTE_USER' => 'abeer' }
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    params = Rack::Utils.parse_query(response.redirect_url)
    assert_match "http://#{request.host}/abeer", params['openid.identity']
  end
  
  CHECKID_AND_GROUPS = CHECKID.merge({
    'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
    'openid.ax.mode' => 'fetch_request',
    'openid.ax.type.groups' => 'http://id.meet.mit.edu/schema/groups',
    'openid.ax.required' => 'groups'
  })
  
  test "authenticate with groups via login" do
    get login_url, CHECKID_AND_GROUPS, { 'REMOTE_USER' => 'anat' }
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=allstaff/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=exec/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=founders/, response.redirect_url
  end
  
  CHECKID_AND_ATTRS = CHECKID_AND_GROUPS.merge({
    'openid.ax.type.username' => 'http://axschema.org/namePerson/friendly',
    'openid.ax.required' => 'username,groups'
  })
  
  def ns_alias_for(params, uri)
    params.find { |x, v| v == uri } [0].sub('.type.', '.value.')
  end
  
  test "login then get attributes via session" do
    post openid_url, CHECKID
    assert_redirected_to login_url(CHECKID)
    
    get response.location, {}, { 'REMOTE_USER' => 'aleksandra' }
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    params = Rack::Utils.parse_query(response.redirect_url)
    assert_match "http://#{request.host}/aleksandra", params['openid.identity']
    
    post openid_url, CHECKID_AND_ATTRS
    assert_response :redirect
    params = Rack::Utils.parse_query(response.redirect_url)
    assert_match 'aleksandra', params[ns_alias_for(params, AXSchema::Username) + '.1']
    assert_match 'allstaff', params[ns_alias_for(params, AXSchema::Groups) + '.1']
  end
  
end
