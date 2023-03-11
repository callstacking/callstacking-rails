require 'yaml'
require 'io/console'

module Callstacking
  module Rails
    class Setup
      attr_accessor :settings

      def initialize
        @settings = Callstacking::Rails::Settings.new
      end

      def start
        puts "Login to callstacking.com"
        puts
        
        email      = prompt("Enter email:", echo: true)
        password   = prompt("Enter password:", echo: false)

        settings.save(email, password, url)

        puts "Authentication successful."
        puts "Settings saved to #{Callstacking::Rails::Settings::SETTINGS_FILE}"
        true
      rescue StandardError => e
        puts "Problem authenticating: #{e.message}"
        puts e.backtrace.join("\n")
        false
      end

      def prompt(label, echo: true)
        puts label

        value = echo ? STDIN.gets.chomp : STDIN.noecho(&:gets).chomp
        puts

        return nil if value == ''
        value
      end

      def self.instructions
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
        puts "    Stores auth details in #{Callstacking::Rails::Settings::SETTINGS_FILE}"
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
        puts " The #{Callstacking::Rails::Env.environment}: section in the #{Callstacking::Rails::Settings::SETTINGS_FILE} contains your credentials."
        puts " By setting the RAILS_ENV environment you can maintain multiple settings."
        puts
        puts "Questions? Create an issue: https://github.com/callstacking/callstacking-rails/issues"
        
        :instructions
      end

      private

      def url
        if (Callstacking::Rails::Env.production? || ::Rails.env.test?) &&
          ENV['CALLSTACKING_RAILS_LOCAL_TEST'].nil?
          Callstacking::Rails::Settings::PRODUCTION_URL
        else
          prompt("Enter URL for #{Callstacking::Rails::Env.environment} API calls [#{Callstacking::Rails::Settings::PRODUCTION_URL}]:") ||
              Callstacking::Rails::Settings::PRODUCTION_URL
        end
      end
    end
  end
end