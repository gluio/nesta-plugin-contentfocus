require "redcarpet"
require "nesta-plugin-drop/client"
require "nesta-plugin-drop/helpers"
require "nesta-plugin-drop/routes"
module Nesta
  class App
    include Nesta::Plugin::Drop::Routes
    helpers Nesta::Plugin::Drop::Helpers
    before do
      check_nestadrop
    end

    not_found do
      if Nesta::Plugin::Drop::Client.syncing?
        filename = File.expand_path("assets/loading.html", File.dirname(__FILE__))
        template = File.read(filename)
        return template
      else
        set_common_variables
        haml(:not_found)
      end
    end

    error do
      set_common_variables
      haml(:error)
    end

  end
end
