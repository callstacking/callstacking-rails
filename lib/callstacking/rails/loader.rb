require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :root, :spans, :instrumenter, :klasses, :excluded
      def initialize(instrumenter, excluded: [])
        @root = Regexp.new(::Rails.root.to_s)
        @spans = spans
        @excluded = excluded
        @instrumenter = instrumenter
        @klasses = Set.new
      end

      def on_load
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          exclude = excluded.any? { |ex| path =~ /#{ex}/ }

          if path =~ root && !exclude
            instrumenter.instrument_klass(klass)
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