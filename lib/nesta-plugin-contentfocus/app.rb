require "redcarpet"
require "sinatra/cookies"
require "nesta-plugin-contentfocus/client"
require "nesta-plugin-contentfocus/helpers"
require "nesta-plugin-contentfocus/middleware"
require "nesta-plugin-contentfocus/routes"
module Nesta
  class App < Sinatra::Base
    include Nesta::Plugin::ContentFocus::Routes
    helpers Nesta::Plugin::ContentFocus::Helpers
    helpers Sinatra::Cookies
    use Nesta::Plugin::ContentFocus::Middleware

    before do
      check_contentfocus
      if session[:person_id]
        response.set_cookie('person_id',
          value: session[:person_id],
          domain: ENV['BASE_DOMAIN'],
          path: '/')
      end
    end

    not_found do
      if Nesta::Plugin::ContentFocus::Client.syncing?
        filename = File.expand_path("assets/loading.html", File.dirname(__FILE__))
        template = File.read(filename)
        return template
      else
        set_common_variables
        haml(:not_found)
      end
    end

    error SocketError do
      if !Nesta::Plugin::ContentFocus::Client.installed?
        filename = File.expand_path("assets/install.html", File.dirname(__FILE__))
        template = File.read(filename)
        return template
      else
        set_common_variables
        haml(:error)
      end
    end

    error do
      set_common_variables
      haml(:error)
    end

  end
end
