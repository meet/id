ENV["RAILS_ENV"] = "test"
require 'directory/test_help'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  
  def parse_query(url)
    Rack::Utils.parse_query(url.split('?', 2)[1])
  end
  
end
