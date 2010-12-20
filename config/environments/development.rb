Id::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  class Development
    def initialize(app)
      @app = app
      @auth = Rack::Auth::Basic.new(app, "Development") { |username, password|
        password == Time.now.min.to_s
      }
    end
    def call(env)
      # Assume LDAP is port forwarded
      Directory.connect_with(:port => 3389)
      
      # Simulate Apache authentication
      if /\/login/ =~ env['PATH_INFO']
        @auth.call(env)
      else
        @app.call(env)
      end
    end
  end
  config.middleware.use Development
  
end
