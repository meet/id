Id::Application.routes.draw do
  
  match 'openid' => 'server#openid', :as => :openid
  post 'login' => 'server#login', :as => :login
  
  root :to => 'discovery#idp'
  match 'xrds' => 'discovery#idp.xrds_xml', :as => :idp_xrds
  match ':username' => 'discovery#user', :as => :user
  match ':username/xrds' => 'discovery#user.xrds_xml', :as => :user_xrds
  
end
