# encoding: utf-8
require 'rack'
module Nesta
  module Plugin
    module ContentFocus
      class Middleware

        def initialize(app, options={})
          @app = app
        end

        def javascript
          return nil unless Client.installed?
          %Q{<script src="//cdn.contentfocus.io/#{Client.username}.js" async></script>}
        end

        def call(env)
          result = @app.call(env)
          if javascript && inject?(env, result[0], result[1])
            html = insert_html(result[2], result[1], javascript)
            env['contentfocus.javascript'] = true
            if html
              response = Rack::Response.new(html, result[0], result[1])
              response.finish
            else
              result
            end
          else
            result
          end
        end

        def inject?(env, status, headers)
          status == 200 &&
          !env['contentfocus.javascript'] &&
          html?(headers) &&
          !attachment?(headers)
        end

        def html?(headers)
          headers['Content-Type'] && headers['Content-Type'].include?('text/html')
        end

        def attachment?(headers)
          headers['Content-Disposition'] && headers['Content-Disposition'].include?('attachment')
        end

        def insert_html(response, headers, html)
          source = concat_response(response)
          close_response(response)
          return nil unless source
          source_chunk = source[0..60000]
          if body_start = body_index(source_chunk)
            meta_indexes = [
              meta_ua_compatible_index(source_chunk),
              meta_charset_index(source_chunk)
            ].compact
            if !meta_indexes.empty?
              insertion_index = meta_indexes.max
            else
              insertion_index = head_open_index(source_chunk) || body_start
            end
            if insertion_index
              source = source[0...insertion_index] <<
                html <<
                source[insertion_index..-1]
            else
              # Unable to find insertion point
            end
          else
            # Unable to find start of <body>
          end
          source
        rescue => e
          # TODO: revisit this
          nil
        end

        def concat_response(response)
          source = nil
          response.each {|fragment| source ? (source << fragment.to_s) : (source = fragment.to_s)}
          source
        end

        def close_response(response)
          if response.respond_to?(:close)
            response.close
          end
        end

        def body_index(head)
          head.index('<body')
        end

        def meta_ua_compatible_index(head)
          match = head.match(/<\s*meta[^>]+http-equiv\s*=\s*['"]x-ua-compatible['"][^>]*>/im)
          match.end(0) if match
        end

        def meta_charset_index(head)
          match = head.match(/<\s*meta[^>]+charset\s*=[^>]*>/im)
          match.end(0) if match
        end

        def head_open_index(head)
          head_open = head.index('<head')
          beginning_of_source.index('>', head_open) + 1 if head_open
        end
      end
    end
  end
end
