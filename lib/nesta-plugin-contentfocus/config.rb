require 'nesta-plugin-contentfocus/client'
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
          Client.get_json("config")
        end

        def self.set(hash)
          hash.each do |k,v|
            ENV[k] ||= v
          end
        end
      end
    end
  end
end
