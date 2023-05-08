require "rails"
require "active_support/cache"
require "callstacking/rails/env"
require "callstacking/rails/trace"
require "callstacking/rails/instrument"
require 'callstacking/rails/spans'
require "callstacking/rails/setup"
require "callstacking/rails/settings"
require "callstacking/rails/loader"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/cli"
require "callstacking/rails/time_based_uuid"
require "callstacking/rails/helpers/instrument_helper"

module Callstacking
  module Rails
    class Engine < ::Rails::Engine
      EXCLUDED_TEST_CLASSES = %w[test/dummy/app/models/salutation.rb test/dummy/app/controllers/application_controller.rb].freeze
      
      cattr_accessor :spans, :trace, :settings, :instrumenter, :loader

      isolate_namespace Callstacking::Rails

      @@settings||=Callstacking::Rails::Settings.new
      @@spans||=Spans.new
      @@trace||=Trace.new(@@spans)
      @@instrumenter||=Instrument.new(@@spans)

      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      config.after_initialize do
        puts "Call Stacking loading (#{Callstacking::Rails::Env.environment})"
          
        @@loader = Callstacking::Rails::Loader.new(@@instrumenter, excluded: @@settings.excluded + EXCLUDED_TEST_CLASSES)
        @@loader.on_load
      end

      def self.start_tracing(controller)
        @@settings.enable!
        @@loader.reset!
        @@instrumenter.enable!(@@loader.klasses.to_a)
        @@trace.begin_trace(controller)

        true
      end

      def self.stop_tracing(controller)
        @@settings.disable!
        @@instrumenter.disable!
        @@trace.end_trace(controller)

        true
      end
    end
  end
end
