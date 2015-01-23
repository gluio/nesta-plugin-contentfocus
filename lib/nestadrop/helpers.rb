module Nesta
  module Plugin
    module Drop
      module Helpers
        def nestadrop_configured?
          Client.nestadrop_configured?
        end

        def setup_nestadrop
          redirect to("#{Nesta::Plugin::Drop::Client.host}/?domain=#{request.host}&key=#{ENV["NDROP_KEY"]}")
        end

        def check_nestadrop
          return if request.path_info =~ %r{\A/nestadrop\z}
          setup_nestadrop unless nestadrop_configured?
        end

        def nestadrop_request?
          params["KEY"] == ENV["NDROP_KEY"]
        end
      end
    end
  end
end
