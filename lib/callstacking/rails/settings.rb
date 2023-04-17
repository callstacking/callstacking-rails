require "active_support/cache"
require "active_support/concern"
require "active_support/core_ext/class/attribute_accessors"

module Callstacking
  module Rails
    class Settings
      attr_accessor :settings
      attr_reader :client

      SETTINGS_FILE = "#{Dir.home}/.callstacking"
      PRODUCTION_URL = "https://callstacking.com"
      ENV_KEY        = 'CALLSTACKING_ENABLED'
      CACHE_KEY      = :callstacking_enabled

      def initialize
        read_settings
        @client = Callstacking::Rails::Client::Authenticate.new(url, auth_token)
      end

      def url
        settings[:url] || PRODUCTION_URL
      end

      def auth_token
        ENV['CALLSTACKING_API_TOKEN'] || settings[:auth_token]
      end

      def auth_token?
        !auth_token.nil?
      end

      def write_settings(new_settings)
        File.write(SETTINGS_FILE, new_settings.to_yaml)
      end

      def self.enable!
        ::Rails.cache.write(CACHE_KEY, true)
      end
      def enable!
        self.class.enable!
      end

      def self.disable!
        ::Rails.cache.write(CACHE_KEY, false)
      end

      def disable!
        self.class.disable!
      end

      def enabled?
        return ::Rails.cache.read(CACHE_KEY) unless ::Rails.cache.read(CACHE_KEY).nil?
        return false if ENV[ENV_KEY] == 'false'
        return false if settings.nil?
        
        settings[:enabled]
      end

      def excluded
        settings[:excluded] || []
      end

      def disabled?
        !enabled?
      end

      def save(email, password, url)
        props = { auth_token: '',
                  url: url,
                  enabled: true
        }

        props = { Callstacking::Rails::Env.environment => {
          settings: props
        } }

        write_settings(complete_settings.merge(props))

        props[Callstacking::Rails::Env.environment][:settings][:auth_token] = token(email, password)

        write_settings(complete_settings.merge(props))

        read_settings
      end

      def enable_disable(enabled: true)
        settings[:enabled] = enabled

        props = { Callstacking::Rails::Env.environment => {
          settings: settings
        } }

        write_settings(complete_settings.merge(props))
      end

      private

      def token(email, password)
        client.login(email, password)
      end

      def read_settings
        @settings = complete_settings.dig(::Callstacking::Rails::Env.environment, :settings) || {}
      rescue StandardError => e
        puts e.full_message
        puts e.backtrace.join("\n")
        return {}
      end

      def complete_settings
        YAML.load(File.read(SETTINGS_FILE)) rescue {}
      end
    end
  end
end