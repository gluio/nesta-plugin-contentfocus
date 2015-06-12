module Nesta
  module Plugin
    module ContentFocus
      module Routes
        def self.included(app)
          app.post "/contentfocus" do
            if !contentfocus_request?
              status 404
            else
              if params["file"]
                Thread.new do
                  Nesta::Plugin::ContentFocus::Client.cache_file(params["file"])
                end
              else
                Thread.new do
                  Nesta::Plugin::ContentFocus::Client.cache_files
                end
              end
              status 200
              ""
            end
          end

          app.delete "/contentfocus" do
            if !contentfocus_request?
              status 404
            else
              if params["file"]
                Thread.new do
                  Nesta::Plugin::ContentFocus::Client.remove_file(params["file"])
                end
              end
              status 200
              ""
            end
          end

          app.put "/contentfocus" do
            if !contentfocus_request?
              status 404
            else
              Thread.new do
                Nesta::Plugin::ContentFocus::Client.bounce_server!
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
