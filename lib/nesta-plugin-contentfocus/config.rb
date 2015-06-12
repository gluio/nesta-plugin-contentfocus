require 'nesta-plugin-contentfocus/client'
require 'nesta-plugin-contentfocus/logger'
module Nesta
  module Plugin
    module ContentFocus
      class Config
        def self.excluded_config
          @excluded_config ||= ENV.keys.sort
        end

        def self.setup!
          if Client.installed?
            set(get)
          end
        rescue Exception => ex
          Nesta::Plugin::ContentFocus.logger.error "CONTENTFOCUS: Error setting config."
          Nesta::Plugin::ContentFocus.logger.error ex.to_s
        end

        def self.get
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Fetching app configuration settings"
          Client.get_json("config", { exclude: excluded_config.join(",") }, encrypt: true)
        end

        def self.set(hash)
          hash.reject!{|k,v| excluded_config.include? k }
          hash.each do |k,v|
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Setting configuration setting for #{k}"
            ENV[k] = v
          end
        end
      end
    end
  end
end
