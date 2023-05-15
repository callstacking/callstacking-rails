require "rails"
require "callstacking/rails/logger"

module Callstacking
  module Rails
    class Loader
      attr_accessor :instrumenter, :klasses, :excluded
      def initialize(instrumenter, excluded: [])
        @excluded = excluded
        @instrumenter = instrumenter
        @klasses = Set.new
      end

      def instrument_existing
        objs = []
        ObjectSpace.each_object(Module){|ob| objs << [ob, ((Object.const_source_location(ob.to_s) rescue nil))].flatten}
        objs.each{|o| filter_klass(o.first, o.last)}
      end

      def on_load
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          Logger.log("Callstacking::Rails::Loader.on_load #{klass} #{path}")
          Logger.log("English defined? #{Object.const_defined?('English')}")

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
        excluded_klass = excluded.any? { |ex| path =~ /#{ex}/ }

        if path =~ /#{::Rails.root.to_s}/ &&
          !klasses.include?(klass) &&
          !excluded_klass
          instrumenter.instrument_klass(klass)
          klasses << klass
        end
      end
    end
  end
end