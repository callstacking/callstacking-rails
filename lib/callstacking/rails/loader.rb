require "rails"
require "callstacking/rails/logger"

module Callstacking
  module Rails
    class Loader
      attr_accessor :instrumenter, :klasses, :excluded, :settings
      def initialize(instrumenter, excluded: [])
        @excluded = excluded
        @instrumenter = instrumenter
        @klasses = Set.new
        @settings = Callstacking::Rails::Settings.new

        preloaded_klasses
      end

      def preloaded_klasses
        ObjectSpace.each_object(Module){|ob| filter_klass(ob, (Object.const_source_location(ob.to_s)&.first rescue nil))}
      end

      def on_load
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          filter_klass(klass, path)
        end

        trace.enable
      end

      def reset!
        instrumenter.instrument_method(ActionView::PartialRenderer, :render, application_level: false)
        instrumenter.instrument_method(ActionView::TemplateRenderer, :render, application_level: false)
      end

      private
      def filter_klass(klass, path)
        return if klass.nil? || path.nil?
        return if path == false

        excluded_klass = excluded.any? { |ex| path =~ /#{ex}/ }

        if path =~ /#{::Rails.root.to_s}/ &&
          !klasses.include?(klass) &&
          !excluded_klass
          instrumenter.instrument_klass(klass) if settings.enabled?
          klasses << klass
        end
      end
    end
  end
end