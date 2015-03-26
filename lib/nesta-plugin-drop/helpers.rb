require 'nesta-plugin-drop/logger'
module Nesta
  module Plugin
    module Drop
      module Helpers
        def nestadrop_configured?
          Client.nestadrop_configured?
        end

        def setup_nestadrop
          Nesta::Plugin::Drop.logger.debug "NESTADROP: Redirecting to nestadrop.io to complete account setup."
          redirect to("#{Nesta::Plugin::Drop::Client.host}account/setup?domain=#{request.host}")
        end

        def check_nestadrop
          return if request.path_info =~ %r{\A/nestadrop\z}
          setup_nestadrop unless nestadrop_configured?
        end

        def nestadrop_request?
          Nesta::Plugin::Drop.logger.debug "NESTADROP: Authenticating Dropbox webhook request..."
          expected_user, expected_pass = Client.userinfo
          auth = Rack::Auth::Basic::Request.new(request.env)
          if auth.provided? && auth.basic? && auth.credentials == [expected_user, expected_pass]
            Nesta::Plugin::Drop.logger.debug "NESTADROP: Authenticated."
            return true
          else
            Nesta::Plugin::Drop.logger.debug "NESTADROP: Authentication failed."
            return false
          end
        end
      end
    end
  end
end
