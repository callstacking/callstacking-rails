require "active_support/concern"
require "active_support/core_ext/class/attribute_accessors"
require "callstacking/rails/env"

module Callstacking
  module Rails
    module Settings
      extend ActiveSupport::Concern

      included do |base|
        attr_accessor :settings
      end

      SETTINGS_FILE = "#{Dir.home}/.callstacking-rails"
      PRODUCTION_URL = "https://callstacking.com"

      def url
        settings[:url]
      end

      def auth_token
        settings[:auth_token]
      end

      def auth_token?
        auth_token.present?
      end

      def write_settings(new_settings)
        File.write(SETTINGS_FILE, new_settings.to_yaml)
      end

      def enabled?
        settings[:enabled]
      end

      def disabled?
        !enabled?
      end

      def read_settings
        @@settings = @settings = complete_settings.dig(::Callstacking::Rails::Env.environment, :settings)
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