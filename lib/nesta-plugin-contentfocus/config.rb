require 'nesta-plugin-contentfocus/client'
require 'nesta-plugin-contentfocus/logger'
module Nesta
  module Plugin
    module ContentFocus
      class Config
        def self.setup!
          if Client.installed?
            set(get)
          end
        end

        def self.get
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Fetching app configuration settings"
          Client.get_json("config")
        end

        def self.set(hash)
          hash.each do |k,v|
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Setting configuration setting for #{k}"
            ENV[k] ||= v
          end
        end
      end
    end
  end
end
