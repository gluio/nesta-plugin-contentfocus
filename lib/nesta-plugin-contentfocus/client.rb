require 'rest_client'
require 'yajl'
require 'nesta-plugin-contentfocus/logger'
module Nesta
  module Plugin
    module ContentFocus
      class Client
        def self.host
          ENV["CONTENTFOCUS_URL"]
        end

        def self.userinfo
          URI.parse(host).userinfo.split(":")
        end

        def self.get(path, headers = {})
          defaults = { x_contentfocus_version: Nesta::Plugin::ContentFocus::VERSION }
          RestClient.get URI.join(host, path).to_s, defaults.merge(headers)
        end

        def self.get_json(path)
          json = get(path, accept: :json)
          Yajl::Parser.parse json
        end

        def self.lock
          @lock ||= Mutex.new
        end

        def self.installed?
          !host.nil? && host != ""
        end

        def self.confirm_synced!
          return true if contentfocus_synced?
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Syncing with Dropbox filesystem."
          File.open("/tmp/.contentfocus", "w+") do |f|
            f.write "synced"
          end
        end

        def self.syncing?
          lock.synchronize do
            @syncing
          end
        end

        def self.contentfocus_synced?
          File.exists?("/tmp/.contentfocus")
        end

        def self.contentfocus_configured?
          return true if contentfocus_synced?
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Checking if account is linked to Dropbox."
          account = get_json("account")
          account["uid"] && account["token"] && account["domain"]
        end

        def self.bounce_server!
          return if syncing?
          Nesta::Plugin::ContentFocus.logger.info "CONTENTFOCUS: Purging nesta file cache."
          Nesta::FileModel.purge_cache
          Nesta::Plugin::ContentFocus.logger.info "CONTENTFOCUS: Restarting server..."
          unless system("bundle exec pumactl -S /tmp/.app_state phased-restart")
            Thread.new do
              Nesta::Plugin::ContentFocus.logger.info "CONTENTFOCUS: Waiting for server to load before restarting."
              sleep(3)
              bounce_server!
            end
          end
        end

        def self.files
          lock.synchronize do
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Retrieving file list..."
            @files ||= get_json("files")
          end
          @files
        rescue RestClient::Unauthorized
          return []
        end

        def self.uncached_files
          @uncached_files
        end

        def self.uncached_files=(val)
          lock.synchronize do
            @uncached_files ||= val
          end
          @uncached_files
        end

        def self.cache_file(file)
          confirm_synced!
          local_path = [Nesta::App.root, file].join("/")
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Caching '#{file}' to local filesystem at '#{local_path}'..."
          FileUtils.mkdir_p(File.dirname(local_path))
          file_contents = get("file?file=#{URI.encode(file)}")
          File.open(local_path, 'w') do |fo|
            fo.write file_contents
          end
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Cached '#{local_path}'."
          bounce_server!
        rescue RuntimeError => ex
          puts ex
        end

        def self.cache_files
          self.uncached_files = Client.files
          return unless uncached_files.size > 0
          @syncing = true
          threads = []
          5.times do
            threads << Thread.new do
             Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Creating worker thread to cache files..."
              file = nil
              while self.uncached_files.size > 0
                lock.synchronize do
                  file = self.uncached_files.pop
                end
                cache_file(file) if file
              end
            end
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Worker thread complete."
          end
          threads.each(&:join)
          @syncing = false
          bounce_server!
        end

        def self.remove_file(file)
          local_path = [Nesta::App.root, file].join("/")
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Removing locally cached file at '#{local_path}'."
          FileUtils.rm_r(File.dirname(local_path), secure: true)
          bounce_server!
        end

        def self.bootstrap!
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Bootstrapping local instance..."
          unless contentfocus_synced?
            Thread.new do
              cache_files
            end
          end
        end
      end
    end
  end
end
