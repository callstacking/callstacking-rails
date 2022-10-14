require 'yaml'
require "checkpoint/rails/settings"

module Checkpoint
  module Rails
    class Setup
      include ::Checkpoint::Rails::Settings
      extend ::Checkpoint::Rails::Settings

      attr_accessor :client

      def initialize
        read_settings
      end

      def client
        @client = Checkpoint::Rails::Client::Authenticate.new
      end

      def start
        email      = prompt("Enter email:")
        password   = prompt("Enter password:")

        url = if Rails::Checkpoint::Env.production? && ENV['CHECKPOINT_RAILS_LOCAL_TEST'].nil?
                PRODUCTION_URL
              else
                prompt("Enter URL for #{Checkpoint::Rails::Env.environment} API calls [#{PRODUCTION_URL}]:") || PRODUCTION_URL
              end

        save(email, password, url)

        puts "Authentication successful."
        puts "Settings saved to #{SETTINGS_FILE}"
      rescue StandardError => e
        puts "Problem authenticating: #{e.message}"
      end

      def prompt(label)
        puts label
        value = STDIN.gets.chomp
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
        }

        props = { Checkpoint::Rails::Env.environment => {
          settings: props
        } }

        write_settings(complete_settings.merge(props))

        props[Checkpoint::Rails::Env.environment][:settings][:auth_token] = token(email, password)

        write_settings(complete_settings.merge(props))

        read_settings
      end

      def self.instructions
        read_settings
        puts "loading environment #{Checkpoint::Rails::Env.environment}"
        puts
        puts "Usage: "
        puts
        puts "  checkpoint-rails register"
        puts "    Opens a browser window to register as a Market Hackers user."
        puts
        puts "  checkpoint-rails setup"
        puts "    Interactively prompts you for your checkpoint-rails username/password, "
        puts "    Stores auth details in #{SETTINGS_FILE} "
        puts
        puts " You can have multiple environments."
        puts "    Default is #{Rails::Checkpoint::Env::DEFAULT_ENVIRONMENT}."
        puts
        puts " The #{Checkpoint::Rails::Env.environment}: section in the #{SETTINGS_FILE} contains your credentials."
        puts " By setting the RAILS_ENV environment you can maintain"
        puts " multiple settings."
        puts
        puts "Questions? Create an issue: https://github.com/aantix/checkpoint-rails/issues"
      end
    end
  end
end