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
require "callstacking/rails/logger"

module Callstacking
  module Rails
    class Engine < ::Rails::Engine
      EXCLUDED_TEST_CLASSES = %w[test/dummy/app/models/salutation.rb 
                                 test/dummy/app/controllers/application_controller.rb].freeze
      
      cattr_accessor :spans, :traces, :settings, :instrumenter, :loader, :lock

      isolate_namespace Callstacking::Rails

      @@spans||={}
      @@traces||={}
      @@lock||=Mutex.new
      @@instrumenter||=Instrument.new
      @@settings||=Callstacking::Rails::Settings.new

      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      config.after_initialize do
        Logger.log "Call Stacking loading (#{Callstacking::Rails::Env.environment})"

        Logger.log("English defined? #{Object.const_defined?('English')}")

        spans[Thread.current.object_id]||=Spans.new
        instrumenter.add_span(spans[Thread.current.object_id])

        @@loader = Callstacking::Rails::Loader.new(instrumenter, excluded: settings.excluded + EXCLUDED_TEST_CLASSES)
        loader.on_load
        # loader.reset!
      end

      # Serialize all tracing requests for now.
      #  Can enable parallel tracing later.
      def self.start_tracing(controller)
        Logger.log("Callstacking::Rails::Engine.start_tracing")
        
        settings.enable!

        lock.synchronize do
          spans[Thread.current.object_id]||=Spans.new
          span = spans[Thread.current.object_id]

          instrumenter.add_span(span)

          if instrumenter.instrumentation_required?
            Logger.log("Callstacking::Rails::Engine instrumenter.instrumentation_required? #{instrumenter.instrumentation_required?} #{loader.klasses.to_a}")

            loader.reset!
            instrumenter.enable!(loader.klasses.to_a)
          end

          traces[Thread.current.object_id] = Trace.new(span)
          trace = traces[Thread.current.object_id]

          trace.begin_trace(controller)
        end

        true
      end

      def self.stop_tracing(controller)
        Logger.log("Callstacking::Rails::Engine.stop_tracing")
        
        settings.disable!

        trace = nil
        lock.synchronize do
          trace = traces.delete(Thread.current.object_id)
          if traces.empty?
            instrumenter.disable!
          end
        end

        trace&.end_trace(controller)
        
        true
      end
    end
  end
end
