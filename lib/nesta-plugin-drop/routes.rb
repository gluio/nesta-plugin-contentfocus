module Nesta
  module Plugin
    module Drop
      module Routes
        def included(app)
          app.post "/nestadrop" do
            if !nestadrop_request?
              status 404
            else
              if params["file"]
                Thread.new do
                  Nesta::Plugin::Drop::Client.cache_file(params["file"])
                end
              else
                Thread.new do
                  Nesta::Plugin::Drop::Client.cache_files
                end
              end
              status 200
              ""
            end
          end

          app.delete "/nestadrop" do
            if !nestadrop_request?
              status 404
            else
              if params["file"]
                Thread.new do
                  Nesta::Plugin::Drop::Client.remove_file(params["file"])
                end
              end
              status 200
              ""
            end
          end
        end
      end
    end
  end
end
