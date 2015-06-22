require 'nesta-plugin-contentfocus/logger'
module Nesta
  module Plugin
    module ContentFocus
      module Helpers
        def contentfocus_configured?
          Client.contentfocus_configured?
        end

        def contentfocus_installed?
          Client.installed?
        end

        def setup_contentfocus
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Redirecting to contentfocus.io to complete account setup."
          redirect to(Nesta::Plugin::ContentFocus::Client.host_with_token_auth("account/setup", "domain=#{request.host}"))
        end

        def check_contentfocus
          return if request.path_info =~ %r{\A/contentfocus\z}
          setup_contentfocus unless !contentfocus_installed? || contentfocus_configured?
        end

        def contentfocus_request?
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Authenticating Dropbox webhook request..."
          expected_user, expected_pass = Client.userinfo
          auth = Rack::Auth::Basic::Request.new(request.env)
          if auth.provided? && auth.basic? && auth.credentials == [expected_user, expected_pass]
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Authenticated."
            return true
          else
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Authentication failed."
            return false
          end
        end

        def site_domain
          request.host
        end
      end
    end
  end
end
