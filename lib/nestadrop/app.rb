require 'client'
require 'helpers'
require 'routes'
module Nesta
  class App
    include Nesta::Plugin::Drop::Routes
    helpers Nesta::Plugin::Drop::Helpers
    before do
      check_nestadrop
    end

    error do
      Bugsnag.auto_notify($!)
      set_common_variables
      haml(:error)
    end

  end
end
