require 'logger'
module Nesta
  module Plugin
    module ContentFocus
      def self.logger
        return @logger if @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
        if level = ENV["CONTENTFOCUS_LOG_LEVEL"]
          levels = ["FATAL", "ERROR", "WARN", "INFO", "DEBUG"]
          if levels.include? level.upcase
            @logger.level = Logger.const_get(level.upcase.to_sym)
          else
            @logger.warn "Log level '#{level.upcase}' is unknown. Supported levels are: #{levels.join(", ")}."
          end
        end
        @logger
      end
    end
  end
end
