require 'base64'
require 'uri'
require 'encryptor'
require 'pusher-client'
require 'rest_client'
require 'yajl'
require 'websocket-native'
require 'nesta-plugin-contentfocus/logger'
PusherClient.logger = Nesta::Plugin::ContentFocus.logger
module Nesta
  module Plugin
    module ContentFocus
      class Client
        def self.host
          ENV["CONTENTFOCUS_URL"]
        end

        def self.host_with_token_auth(path = nil, query = nil)
          if host
            auth_token = get_json("account/login")["token"]
            query = ["token=#{auth_token}", query].compact.join("&")
            uri = URI.parse(host)
            URI::Generic.new(
              uri.scheme,
              nil,
              uri.host,
              uri.port,
              uri.registry,
              [uri.path, path].compact.join("/").gsub(%r{/{2,}},"/"),
              uri.opaque,
              [uri.query, query].compact.join("&"),
              nil).to_s
          end
        end

        def self.userinfo
          URI.parse(host).userinfo.split(":")
        end

        def self.username
          userinfo.first
        end

        def self.password
          userinfo.last
        end

        def self.get(path, headers = {})
          defaults = { x_contentfocus_version: Nesta::Plugin::ContentFocus::VERSION }
          RestClient.get URI.join(host, path).to_s, defaults.merge(headers)
        end

        def self.get_json(path, params = {}, opts = {})
          if opts[:encrypt] && params
            raise "No shared secret to encrypt with" unless password
            params.each do |k, v|
              params[k] = Base64.encode64(Encryptor.encrypt(value: v, key: password)).encode("UTF-8")
            end
          end
          json = get(path, params: params, accept: :json)
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
          @update_channel_url = (account["update_channel"] || "")
          account["uid"] && account["token"] && account["domain"]
        end

        def self.update_channel?
          installed? && update_channel_url && update_channel_url != ""
        end

        def self.update_channel_url
          return @update_channel_url if @update_channel_url
          account = get_json("account")
          @update_channel_url = (account["update_channel"] || "")
        end

        def self.update_channel_auth(socket_id, channel)
          return unless update_channel?
          response = get_json("account/channel", socket_id: socket_id)
          response["auth"]
        end

        def self.update_channel
          return unless update_channel?
          return @update_channel if @update_channel
          app_key, channel_secret = URI.parse(update_channel_url).userinfo.split(":")
          pusher_opts = {
            encrypted: true,
            auth_method: method(:update_channel_auth),
            logger: Nesta::Plugin::ContentFocus.logger
          }
          @update_channel = PusherClient::Socket.new(app_key, pusher_opts)
          @update_channel
        end

        def self.subscribe_to_updates
          if update_channel
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Subscribing to update channel"
            channel_name = URI.parse(update_channel_url).path.sub(%r{\A/},"")
            user = ENV["DYNO"] || `hostname`
            update_channel.subscribe(channel_name)
            update_channel[channel_name].bind('file-added') do |json|
              data = Yajl::Parser.parse json
              Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Streaming file add received with data: #{data.inspect}"
              cache_file(data["file"], false)
            end
            update_channel[channel_name].bind('file-removed') do |json|
              data = Yajl::Parser.parse json
              Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Streaming file remove received with data: #{data.inspect}"
              remove_file(data["file"], false)
            end
            update_channel[channel_name].bind('config-changed') do |json|
              data = Yajl::Parser.parse json
              Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Streaming config update received with data: #{data.inspect}"
              Thread.new do
                sleep(rand(0.0 ... 3.0))
                bounce_server!
              end
            end
            update_channel.connect(true)
          end
        end

        def self.bounce_server!
          return if syncing?
          Nesta::Plugin::ContentFocus.logger.info "CONTENTFOCUS: Purging nesta file cache."
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

        def self.local_path(file)
          File.expand_path(Nesta::Config.content_path("pages/"+file))
        end

        def self.within_content_path?(file)
          file =~ %r{\A#{File.expand_path(Nesta::Config.content_path)}}
        end

        def self.cache_file(filename, bounce_server = true)
          confirm_synced!
          local_filename = local_path(filename)
          if within_content_path?(local_filename)
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Caching '#{filename}' to local filesystem at '#{local_filename}'..."
            FileUtils.mkdir_p(File.dirname(local_filename))
            file_contents = get("file?file=#{URI.encode(filename)}")
            File.open(local_filename, 'w') do |fo|
              fo.write file_contents
            end
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Cached '#{local_filename}'."
            Nesta::FileModel.purge_cache
            Nesta::Page.find_all
            bounce_server! #if bounce_server
          else
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Did not cache '#{filename}', resolved path outside allowed directory."
          end
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

        def self.remove_file(filename, bounce_server = false)
          local_filename = local_path(filename)
          if within_content_path?(local_filename)
            if File.directory?(local_filename)
              Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Removing '#{filename}' locally cached directory at '#{local_filename}'."
              FileUtils.rm_r(File.dirname(local_filename), secure: true)
            else
              Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Removing '#{filename}' locally cached file at '#{local_filename}'."
              FileUtils.rm(File.dirname(local_filename))
            end
            Nesta::FileModel.purge_cache
            Nesta::Page.find_all
            bounce_server! #if bounce_server
          else
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Did not delete '#{filename}', resolved path outside allowed directory."
          end
        end

        def self.bootstrap!
          Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Bootstrapping local instance..."
          subscribe_to_updates if installed?
          if contentfocus_synced?
            Nesta::Plugin::ContentFocus.logger.debug "CONTENTFOCUS: Already synced..."
          else
            Thread.new do
              cache_files
            end
          end
        end
      end
    end
  end
end
