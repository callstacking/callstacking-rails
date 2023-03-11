module Callstacking
  module Rails
    class Cli
      REGISTER = 'register'
      SETUP = 'setup'
      ENABLE = 'enable'
      DISABLE = 'disable'

      attr_reader :action, :settings

      def initialize(action, settings)
        @action = action
        @settings = settings
      end

      def run
        parse_options
      end

      def self.action(args)
        args[0]&.downcase&.strip
      end

      private

      def parse_options
        case action
        when 'register'
          puts "Open the following URL to register:\n\n"
          puts "  #{settings.url}/users/sign_up\n\n"
          :register

        when 'setup'
          Callstacking::Rails::Setup.new.start
          :setup

        when 'enable'
          settings.enable_disable
          puts "Call Stacking tracing enabled (#{Callstacking::Rails::Env.environment})"
          :enable

        when 'disable'
          settings.enable_disable(enabled: false)
          puts "Call Stacking tracing disabled (#{Callstacking::Rails::Env.environment})"
          :disable
        end
      end
    end
  end
end