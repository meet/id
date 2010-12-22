require 'openid/store/filesystem'

# Handles OpenID authentication.
class ServerController < ApplicationController
  
  protect_from_forgery :except => :openid
  before_filter :authenticate, :only => :login
  before_filter :openid_req
  
  include OpenID::Server
  include OpenID::AX
  AX_USER_MAP = {
    AXSchema::Username => :username,
    AXSchema::Groups => :groups
  }
  
  # Handle a request to the OpenID endpoint.
  def openid
    if @oidreq.kind_of?(CheckIDRequest)
      
      if session[:username]
        login
      elsif @oidreq.id_select and @oidreq.immediate
        render_response @oidreq.answer(false)
      else
        redirect_to login_path(request.request_parameters)
      end 
      
      return
    end
    
    render_response server.handle_request(@oidreq)
  end
  
  # Respond to an OpenID request with the user logged in.
  def login
    @user = User.find(session[:username])
    @identity = user_url(@user.username)
    
    if not @oidreq.id_select and @identity != @oidreq.identity
      render :wrong_identity and return
    end
    
    if not App.find(@oidreq.trust_root)
      render :unknown_site and return
    end
    
    response = @oidreq.answer(true, nil, @identity)
    
    if axreq = FetchRequest.from_openid_request(@oidreq)
      axresponse = FetchResponse.new
      axreq.attributes.each do |attrib|
        if AX_USER_MAP.has_key? attrib.type_uri
          axresponse.set_values(attrib.type_uri, [ @user.send(AX_USER_MAP[attrib.type_uri]) ].flatten)
        end
      end
      response.add_extension(axresponse)
    end
    
    render_response response
  end
  
  private
    
    def server
      @server ||= Server.new(OpenID::Store::Filesystem.new(Rails.root.join('db').join('openid-store')), openid_url)
    end
    
    def openid_req
      begin
        @oidreq = server.decode_request(params)
      rescue ProtocolError => e
        render :text => e.to_s, :status => 500
        return
      end
    end
    
    def render_response(oidresp)
      if oidresp.needs_signing
        signed_response = server.signatory.sign(oidresp)
      end
      web_response = server.encode_response(oidresp)
      
      case web_response.code
      when HTTP_OK
        render :text => web_response.body, :status => 200
      when HTTP_REDIRECT
        redirect_to web_response.headers['location']
      else
        render :text => web_response.body, :status => 400
      end
    end
    
end
