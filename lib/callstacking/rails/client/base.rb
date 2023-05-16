require 'faraday'
require 'faraday/follow_redirects'

module Callstacking
  module Rails
    module Client
      class Error < StandardError; end

      class Base
        attr_accessor :async, :threads
        attr_reader :url, :auth_token

        def initialize(url, auth_token)
          @url = url
          @auth_token = auth_token

          @threads = []
          @async   = false
        end
        def connection
          # https://github.com/lostisland/awesome-faraday
          @connection ||= Faraday.new(url) do |c|
            c.response :json
            c.response :follow_redirects
            c.use Faraday::Response::RaiseError # raise exceptions on 40x, 50x responses
            c.request :json # This will set the "Content-Type" header to application/json and call .to_json on the body
            c.adapter Faraday.default_adapter
            c.options.timeout = 5

            if auth_token.present?
              c.request :authorization, :Bearer, auth_token
            end
          end
        end

        def get(url, params = {}, headers = {})
          if async
            threads << Thread.new do
              connection.get(url, params, headers)
            end
          else
            connection.get(url, params, headers)
          end
        ensure
          Faraday.default_connection.close if async
        end

        def post(url, params = {}, body = {}, headers_ext = {})
          r(:post, url, params, body, headers_ext)
        end

        def patch(url, params = {}, body = {}, headers_ext = {})
          r(:patch, url, params, body, headers_ext)
        end

        def r(action, url, params = {}, body = {}, _headers_ext = {})
          if async
            threads << Thread.new do
              connection.send(action, url) do |req|
                req.params.merge!(params)
                req.body = body
              end
            end
          else
            connection.send(action, url) do |req|
              req.params.merge!(params)
              req.body = body
            end
          end
        ensure
          Faraday.default_connection.close if async
        end
      end
    end
  end
end
