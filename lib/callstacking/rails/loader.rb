require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :instrumenter, :klasses, :excluded
      def initialize(instrumenter, excluded: [])
        @excluded = excluded
        @instrumenter = instrumenter
        @klasses = Set.new
      end

      def on_load
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          excluded_klass = excluded.any? { |ex| path =~ /#{ex}/ }

          if path =~ /#{::Rails.root.to_s}/ &&
            !klasses.include?(klass) &&
            !excluded_klass
              klasses << klass
          end
        end

        trace.enable

        instrumenter.instrument_method(ActionView::PartialRenderer, :render, application_level: false)
        instrumenter.instrument_method(ActionView::TemplateRenderer, :render, application_level: false)
      end
    end
  end
end