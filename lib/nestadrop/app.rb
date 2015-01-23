module Nesta
  class App
    helpers Nesta::Plugin::Drop::Helpers
    before do
      check_nestadrop
    end

    error do
      Bugsnag.auto_notify($!)
      set_common_variables
      haml(:error)
    end

    post "/nestadrop" do
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

    delete "/nestadrop" do
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
