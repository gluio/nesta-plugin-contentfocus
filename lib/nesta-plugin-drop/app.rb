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

    error do
      set_common_variables
      haml(:error)
    end

  end
end
