module Nesta
  module Plugin
    module Drop
      module Helpers
        def nestadrop_configured?
          Client.nestadrop_configured?
        end

        def setup_nestadrop
          redirect to("#{Nesta::Plugin::Drop::Client.host}/?domain=#{request.host}")
        end

        def check_nestadrop
          return if request.path_info =~ %r{\A/nestadrop\z}
          setup_nestadrop unless nestadrop_configured?
        end

        def nestadrop_request?
          expected_user, expected_pass = Client.userinfo
          auth = Rack::Auth::Basic::Request.new(request.env)
          if auth.provided? && auth.basic? && auth.credentials == [expected_user, expected_pass]
            return true
          else
            return false
          end
        end
      end
    end
  end
end
