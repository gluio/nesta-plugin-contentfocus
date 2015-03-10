require 'fileutils'
require 'rest_client'
require 'yajl'
module Nesta
  module Plugin
    module Drop
      class Client
        def self.host
          ENV["NESTADROP_URL"]
        end

        def self.userinfo
          URI.parse(host).userinfo.split(":")
        end

        def self.lock
          @lock ||= Mutex.new
        end

        def self.confirm_synced!
          return true if nestadrop_synced?
          File.open("/tmp/.nestadropped", "w+") do |f|
            f.write "synced"
          end
        end

        def self.syncing?
          lock.synchronize do
            @syncing
          end
        end

        def self.nestadrop_synced?
          File.exists?("/tmp/.nestadropped")
        end

        def self.nestadrop_configured?
          return true if nestadrop_synced?
          json = RestClient.get "#{host}account", {
            accept: :json, x_nestadrop_version: Nesta::Plugin::Drop::VERSION }
          account = Yajl::Parser.parse json
          account["uid"] && account["token"] && account["domain"]
        end

        def self.bounce_server!
          return if syncing?
          pid = Process.ppid
          begin
            puts "Restarting server..."
            Process.kill("USR2", pid)
          rescue Errno::EPERM
            raise if @retried
            @retried = true
            pid = Process.pid
            retry
          end
        end

        def self.files
          lock.synchronize do
            @files ||= Yajl::Parser.parse(RestClient.get "#{host}files", {
              accept: :json, x_nestadrop_version: Nesta::Plugin::Drop::VERSION })
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
          puts "Caching: #{local_path}"
          FileUtils.mkdir_p(File.dirname(local_path))
          file_contents = RestClient.get "#{host}file?file=#{URI.encode(file)}"
          File.open(local_path, 'w') do |fo|
            fo.write file_contents
          end
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
              file = nil
              lock.synchronize do
                file = self.uncached_files.pop
              end
              cache_file(file) if file
            end
          end
          threads.each(&:join)
          @syncing = false
          bounce_server!
        end

        def self.remove_file(file)
          local_path = [Nesta::App.root, file].join("/")
          FileUtils.rm_r(File.dirname(local_path), secure: true)
          bounce_server!
        end

        def self.bootstrap!
          unless nestadrop_synced?
            cache_files
          end
        end
      end
    end
  end
end
