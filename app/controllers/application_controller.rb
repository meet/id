require 'openid'
require 'openid/extensions/ax'

class ApplicationController < ActionController::Base
  
  protect_from_forgery
  
  private
    
    def authenticate
      user = User.find(request.env['REMOTE_USER'])
      if user
        session[:username] = user.username
      else
        render :text => 'Unauthorized', :status => 403
      end
    end
    
end
