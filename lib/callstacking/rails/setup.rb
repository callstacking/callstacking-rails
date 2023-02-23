require 'yaml'
require "callstacking/rails/settings"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/env"
require 'io/console'

module Callstacking
  module Rails
    class Setup
      include ::Callstacking::Rails::Settings
      extend ::Callstacking::Rails::Settings

      attr_accessor :client

      def initialize
        read_settings
      end

      def client
        @client = Callstacking::Rails::Client::Authenticate.new
      end

      def start
        puts "Login to callstacking.com"
        puts
        
        email      = prompt("Enter email:")
        password   = prompt("Enter password:", echo: false)

        save(email, password, url)

        puts "Authentication successful."
        puts "Settings saved to #{SETTINGS_FILE}"
        true
      rescue StandardError => e
        puts "Problem authenticating: #{e.message}"
        puts e.backtrace.join("\n")
        false
      end

      def enable_disable(enabled: true)
        settings[:enabled] = enabled

        props = { Callstacking::Rails::Env.environment => {
          settings: settings
        } }

        write_settings(complete_settings.merge(props))
      end

      def prompt(label, echo: true)
        puts label

        value = echo ? STDIN.gets.chomp : STDIN.noecho(&:gets).chomp
        puts

        return nil if value == ''
        value
      end

      def token(email, password)
        client.login(email, password)
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

      def self.instructions
        read_settings
        puts "loading environment #{Callstacking::Rails::Env.environment}"
        puts
        puts "Usage: "
        puts
        puts "  > callstacking-rails register"
        puts
        puts "    Opens a browser window to register as a callstacking.com user."
        puts
        puts "  > callstacking-rails setup"
        puts
        puts "    Interactively prompts you for your callstacking.com username/password."
        puts "    Stores auth details in #{SETTINGS_FILE}"
        puts
        puts "  > callstacking-rails enable"
        puts
        puts "    Enables the callstacking tracing."
        puts
        puts "  > callstacking-rails disable"
        puts
        puts "    Disables the callstacking tracing."
        puts
        puts " You can have multiple environments."
        puts " The default is #{Callstacking::Rails::Env::DEFAULT_ENVIRONMENT}."
        puts
        puts " The #{Callstacking::Rails::Env.environment}: section in the #{SETTINGS_FILE} contains your credentials."
        puts " By setting the RAILS_ENV environment you can maintain multiple settings."
        puts
        puts "Questions? Create an issue: https://github.com/callstacking/callstacking-rails/issues"
      end

      private

      def url
        if Callstacking::Rails::Env.production? && ENV['CHECKPOINT_RAILS_LOCAL_TEST'].nil?
          PRODUCTION_URL
        else
          prompt("Enter URL for #{Callstacking::Rails::Env.environment} API calls [#{PRODUCTION_URL}]:") || PRODUCTION_URL
        end
      end
    end
  end
end