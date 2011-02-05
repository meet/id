require 'openid/store/filesystem'

# Handles OpenID authentication.
class ServerController < ApplicationController
  
  protect_from_forgery :except => :openid
  before_filter :session_expire
  before_filter :openid_req
  
  include OpenID::Server
  include OpenID::AX
  
  # Handle a request to the OpenID endpoint.
  def openid
    if @oidreq.kind_of?(CheckIDRequest)
      
      if session[:username]
        render_check_id_response
      elsif @oidreq.id_select and @oidreq.immediate
        render_response @oidreq.answer(false)
      elsif not @app
        render :unknown_site
      else
        flash[:openid_req] = @oidreq
        render :login
      end 
      
      return
    end
    
    render_response server.handle_request(@oidreq)
  end
  
  # Handle a request with user login.
  def login
    if params[:login] and
        @user = Directory::User.find(params[:login][:username]) and
        Directory.new.bind(:method => :simple,
                           :username => @user.dn,
                           :password => params[:login][:password])
      session[:username] = @user.username
      session[:valid] = Time.now + 5.minutes
      openid
    else
      flash[:openid_req] = @oidreq
      flash[:message] = 'Incorrect username or password.'
      render :login
    end
  end
  
  private
    
    def server
      @server ||= Server.new(OpenID::Store::Filesystem.new(Rails.root.join('db').join('openid-store')), openid_url)
    end
    
    def session_expire
      if not (session[:valid] and session[:valid] > Time.now)
        session.delete(:username)
      end
    end
    
    def openid_req
      begin
        @oidreq = server.decode_request(params)
      rescue ProtocolError => @error
        if @oidreq = flash.delete(:openid_req)
          return
        else
          render :error, :status => 500 and return
        end
      ensure
        @app = Directory::App.find(@oidreq.trust_root) if @oidreq
      end
    end
    
    # Respond to an OpenID request with the user logged in.
    def render_check_id_response
      @user = Directory::User.find(session[:username])
      @identity = user_url(@user.username)

      if not @oidreq.id_select and @identity != @oidreq.identity
        render :wrong_identity and return
      end

      if not @app
        render :unknown_site and return
      end

      response = @oidreq.answer(true, nil, @identity)

      if axreq = FetchRequest.from_openid_request(@oidreq)
        axresponse = FetchResponse.new
        axreq.attributes.each do |attrib|
          if AXSchema::MAP.has_key? attrib.type_uri
            axresponse.set_values(attrib.type_uri, [ AXSchema::MAP[attrib.type_uri].call(@user) ].flatten)
          end
        end
        response.add_extension(axresponse)
      end

      render_response response
    end
    
    # Render an OpenID response.
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
