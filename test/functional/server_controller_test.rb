require 'test_helper'

class ServerControllerTest < ActionController::TestCase
  
  def setup
    Directory.connection.mock_user(:uid => 'eve')
    Directory.connection.mock_group(:cn => 'foo', :memberuid => [ 'eve' ])
    Directory.connection.mock_bind('eve', 'secret')
    @eve_login = { :login => { :username => 'eve', :password => 'secret' } }
    @eve_id = "http://#{request.host}/eve"
    
    Directory.connection.mock_user(:uid => 'bob')
    Directory.connection.mock_group(:cn => 'one', :memberuid => [ 'bob' ])
    Directory.connection.mock_group(:cn => 'two', :memberuid => [ 'bob' ])
    Directory.connection.mock_bind('bob', 'secret')
    @bob_login = { :login => { :username => 'bob', :password => 'secret' } }
    @bob_id = "http://#{request.host}/bob"
    
    Directory.connection.mock_user(:uid => 'ted')
    (1..40).each { |n| Directory.connection.mock_group(:cn => "group-#{n}", :memberuid => [ 'ted' ]) }
    Directory.connection.mock_bind('ted', 'secret')
    @ted_login = { :login => { :username => 'ted', :password => 'secret' } }
    
    Directory.connection.mock_user(:uid => 'guy', :givenname => 'Guy', :sn => 'Yug')
    Directory.connection.mock_bind('guy', 'secret')
    @guy_login = { :login => { :username => 'guy', :password => 'secret' } }
  end
  
  def teardown
    Directory.connection.clear_mocks
  end
  
  LOCALHOST = 'http://localhost:8001/return'
  CHECKID = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => LOCALHOST
  }
  
  test "should deny unknown site" do
    post :openid, CHECKID
    assert_response :success
    assert_template :unknown_site
  end
  
  test "should require login" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :openid, CHECKID
    assert_response :success
    assert_template :login
  end
  
  test "should allow via session" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    request.session[:username] = 'eve'
    request.session[:valid] = Time.now + 1.minute
    post :openid, CHECKID
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should require login for expired session" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    request.session[:username] = 'eve'
    request.session[:valid] = Time.now - 1.minute
    post :openid, CHECKID
    assert_response :success
    assert_template :login
  end
  
  test "should deny immediate expired session" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    request.session[:username] = 'eve'
    request.session[:valid] = Time.now - 1.minute
    post :openid, CHECKID.merge('openid.mode' => 'checkid_immediate')
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal 'setup_needed', parse_query(response.redirect_url)['openid.mode']
  end
  
  test "should deny unknown site via session" do
    Directory.connection.mock_app(:ou => 'http://other.host/', :labeleduri => 'http://other.host/')
    request.session[:username] = 'eve'
    request.session[:valid] = Time.now + 1.minute
    post :openid, CHECKID
    assert_response :success
    assert_template :unknown_site
  end
  
  test "should allow via prompted login" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :openid, CHECKID
    assert_response :success
    assert_template :login
    post :login, @eve_login
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should allow via posted login" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID.merge(@eve_login)
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny via bad logins then allow" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :openid, CHECKID
    for params in [ { },
                    { :login => { } },
                    { :login => { :username => 'eve' } },
                    { :login => { :username => 'eve', :password => 'wrong' } } ]
      post :login, params
      assert_response :success
      assert_template :login
      assert_match /incorrect/i, flash[:message]
    end
    post :login, @eve_login
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny unknown site via login" do
    Directory.connection.mock_app(:ou => 'http://other.host/', :labeleduri => 'http://other.host/')
    post :login, CHECKID.merge(@eve_login)
    assert_response :success
    assert_template :unknown_site
  end
  
  test "should allow correct identity" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID.merge(@eve_login).merge({ 'openid.identity' => @eve_id, 'openid.claimed_id' => @eve_id })
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    assert_equal @eve_id, parse_query(response.redirect_url)['openid.identity']
  end
  
  test "should deny wrong identity" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    id = "http://#{request.host}/alice"
    post :login, CHECKID.merge(@eve_login).merge({ 'openid.identity' => id, 'openid.claimed_id' => id })
    assert_response :success
    assert_template :wrong_identity
  end
  
  USERNAME = 'http://axschema.org/namePerson/friendly'
  CHECKID_AND_USERNAME = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => LOCALHOST,
    'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
    'openid.ax.mode' => 'fetch_request',
    'openid.ax.type.username' => USERNAME,
    'openid.ax.required' => 'username'
  }
  
  test "should allow with username via login" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID_AND_USERNAME.merge(@bob_login)
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_equal @bob_id, params['openid.identity']
    assert_equal USERNAME, params['openid.ax.type.ext0']
    assert_equal 'bob', case params['openid.ax.count.ext0']
      when '1' then params['openid.ax.value.ext0.1']
      when nil then params['openid.ax.value.ext0']
      else fail 'Unexpected username count'
    end
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
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID_AND_GROUPS.merge(@bob_login)
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_equal @bob_id, params['openid.identity']
    assert_equal GROUPS, params['openid.ax.type.ext0']
    assert_equal '2', params['openid.ax.count.ext0']
    assert_equal 'one', params['openid.ax.value.ext0.1']
    assert_equal 'two', params['openid.ax.value.ext0.2']
  end
  
  test "should present form with many groups" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID_AND_GROUPS.merge(@ted_login)
    assert_response :success
    assert_select "form[action=#{LOCALHOST}]"
    assert_select "input[name=openid.ax.value.ext0.40]", 1 do |elts|
      assert_equal 'group-40', elts[0]['value']
    end
  end
  
  test "should avoid form with compact groups" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID_AND_GROUPS.merge(@ted_login).merge('openid.ax.type.groups' => 'http://id.meet.mit.edu/schema/groups-csv')
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    params = parse_query(response.redirect_url)
    assert_match /group-1,group-2,.*,group-40/, case params['openid.ax.count.ext0']
      when '1' then params['openid.ax.value.ext0.1']
      when nil then params['openid.ax.value.ext0']
      else fail 'Unexpected groups-csv count'
    end
  end
  
  FIRST_NAME = 'http://axschema.org/namePerson/first'
  LAST_NAME = 'http://axschema.org/namePerson/last'
  FULL_NAME = 'http://id.meet.mit.edu/schema/name-full'
  CHECKID_AND_NAMES = {
    'openid.ns' => 'http://specs.openid.net/auth/2.0',
    'openid.mode' => 'checkid_setup',
    'openid.identity' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.claimed_id' => 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.return_to' => LOCALHOST,
    'openid.ns.ax' => 'http://openid.net/srv/ax/1.0',
    'openid.ax.mode' => 'fetch_request',
    'openid.ax.type.first' => FIRST_NAME,
    'openid.ax.type.last' => LAST_NAME,
    'openid.ax.type.full' => FULL_NAME,
    'openid.ax.required' => 'first,last,full'
  }
  
  test "should provide user's names" do
    Directory.connection.mock_app(:ou => LOCALHOST, :labeleduri => LOCALHOST)
    post :login, CHECKID_AND_NAMES.merge(@guy_login)
    assert_response :redirect
    assert_match /^#{LOCALHOST}/, response.redirect_url
    params = parse_query(response.redirect_url)
    expected = { FIRST_NAME => 'Guy', LAST_NAME => 'Yug', FULL_NAME => 'Guy Yug' }
    for i in 0..2
      assert_equal expected[params["openid.ax.type.ext#{i}"]], case params["openid.ax.count.ext#{i}"]
        when '1' then params["openid.ax.value.ext#{i}.1"]
        when nil then params["openid.ax.value.ext#{i}"]
        else fail "Unexpected count for #{params["openid.ax.type.ext#{i}"]}"
      end
    end
  end
  
end
