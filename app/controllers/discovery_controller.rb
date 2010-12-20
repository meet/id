# Handles OpenID discovery.
class DiscoveryController < ApplicationController
  
  # ID provider page.
  def idp
    @xrds_url = idp_xrds_url
    respond_to do |format|
      format.xrds_xml
      format.html { response.headers['X-XRDS-Location'] = idp_xrds_url }
    end
  end
  
  # User page.
  def user
    @xrds_url = user_xrds_url
    respond_to do |format|
      format.xrds_xml
      format.html { response.headers['X-XRDS-Location'] = user_xrds_url }
    end
  end
  
end
