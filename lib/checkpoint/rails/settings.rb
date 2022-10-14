require "active_support/concern"
require "active_support/core_ext/class/attribute_accessors"

module Checkpoint
  module Rails
    module Settings
      extend ActiveSupport::Concern

      included do |base|
        attr_accessor :settings
      end

      SETTINGS_FILE = "#{Dir.home}/.checkpoint-rails"
      PRODUCTION_URL = "https://www.checkpoint.cx"
      DEFAULT_ENVIRONMENT = "development"

      def url
        settings[:url]
      end

      def auth_token
        settings[:auth_token]
      end

      def auth_token?
        auth_token.present?
      end

      def production?
        Checkpoint::Rails.environment == DEFAULT_ENVIRONMENT.parameterize(separator: '_').to_sym
      end

      def write_settings(new_settings)
        File.write(SETTINGS_FILE, new_settings.to_yaml)
      end

      def read_settings
        @@settings = @settings = complete_settings.dig(Checkpoint::Rails.environment, :settings)
      rescue StandardError => e
        puts e.full_message
        puts e.backtrace.join("\n")
        return {}
      end

      def complete_settings
        YAML.load(File.read(Checkpoint::Rails::Client::Base::SETTINGS_FILE)) rescue {}
      end
    end
  end
end