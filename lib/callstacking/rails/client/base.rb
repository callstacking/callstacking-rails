require 'faraday'
require 'faraday/follow_redirects'
require "callstacking/rails/settings"

module Callstacking
  module Rails
    module Client
      class Error < StandardError; end

      class Base
        include Callstacking::Rails::Settings

        def initialize
          read_settings
        end

        def connection
          # https://github.com/lostisland/awesome-faraday
          @connection ||= Faraday.new(url) do |c|
            c.response :json
            c.use Faraday::Response::Logger, Logger.new('/tmp/callstacking-rails.log')
            # c.use Faraday::Response::Logger, nil, { headers: false, bodies: false }
            c.response :follow_redirects
            c.use Faraday::Response::RaiseError # raise exceptions on 40x, 50x responses
            c.request :json # This will set the "Content-Type" header to application/json and call .to_json on the body
            c.adapter Faraday.default_adapter

            if auth_token?
              c.request :authorization, :Bearer, auth_token
            end
          end
        end

        def get(url, params = {})
          connection.get(url, params, headers)
        end

        def post(url, params = {}, body = {}, headers_ext = {})
          r(:post, url, params, body, headers_ext)
        end

        def patch(url, params = {}, body = {}, headers_ext = {})
          r(:patch, url, params, body, headers_ext)
        end

        def r(action, url, params = {}, body = {}, _headers_ext = {})
          connection.send(action, url) do |req|
            req.params.merge!(params)
            req.body = body
          end
        end

      end
    end
  end
end
