require 'test_helper'

class ApplicationFlowsTest < ActionController::IntegrationTest
  
  class AlmostNetLDAP < Net::LDAP
    def bind(args)
      return args[:password] == 'magic'
    end
  end
  
  def setup
    @backend = Directory.backend
    Directory.backend = AlmostNetLDAP
    Directory.connect_with(:port => 3389)
  end
  
  def teardown
    Directory.backend = @backend
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
    assert_response :success
    assert_template :login
    assert_select 'form[action=?]', login_path
    
    post login_url, { :login => { :username => 'abeer', :password => 'magic' } }
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_equal "http://#{request.host}/abeer", params['openid.identity']
  end
  
  test "fail to authenticate" do
    post openid_url, CHECKID
    assert_response :success
    assert_template :login
    
    post login_url, { :login => { :username => 'abeer', :password => 'wrong' } }
    assert_response :success
    assert_template :login
  end
  
  CHECKID_AND_GROUPS = CHECKID.merge({
    'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
    'openid.ax.mode' => 'fetch_request',
    'openid.ax.type.groups' => 'http://id.meet.mit.edu/schema/groups',
    'openid.ax.required' => 'groups'
  })
  
  test "authenticate with groups via login" do
    post login_url, CHECKID_AND_GROUPS.merge({ :login => { :username => 'anat', :password => 'magic' } })
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=all-staff/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=exec/, response.redirect_url
    assert_match /openid\.ax\.value\.ext0\..=founders/, response.redirect_url
  end
  
  CHECKID_AND_ATTRS = CHECKID_AND_GROUPS.merge({
    'openid.ax.type.username' => 'http://axschema.org/namePerson/friendly',
    'openid.ax.type.groups-csv' => 'http://id.meet.mit.edu/schema/groups-csv',
    'openid.ax.required' => 'username,groups,groups-csv'
  })
  
  def ns_key(params, uri, type)
    params.find { |x, v| v == uri } [0].sub('.type.', ".#{type}.")
  end
  
  test "login then get attributes via session" do
    post openid_url, CHECKID
    assert_response :success
    assert_template :login
    
    post login_url, { :login => { :username => 'aleksandra', :password => 'magic' } }
    assert_response :redirect
    assert_match /^http:\/\/localhost:8001\/return\?/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_match "http://#{request.host}/aleksandra", params['openid.identity']
    
    post openid_url, CHECKID_AND_ATTRS
    assert_response :redirect
    params = parse_query(response.redirect_url)
    assert_equal '1', params[ns_key(params, AXSchema::USERNAME, 'count')]
    assert_equal 'aleksandra', params[ns_key(params, AXSchema::USERNAME, 'value') + '.1']
    assert_equal 'all-staff', params[ns_key(params, AXSchema::GROUPS, 'value') + '.1']
    assert_match /.*all-staff,.*mit/, params[ns_key(params, AXSchema::GROUPS_CSV, 'value') + '.1']
  end
  
end
