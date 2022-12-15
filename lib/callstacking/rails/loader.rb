require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :loader, :root, :once
      def initialize
        @root = Regexp.new(::Rails.root.to_s)
      end

      def on_load(spans)
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          Instrument.new(spans, klass).instrument_klass if path =~ root
        end

        trace.enable

        Instrument.new(spans, ActionView::PartialRenderer).instrument_method(:render,
                                                                             application_level: false)
        
        Instrument.new(spans, ActionView::TemplateRenderer).instrument_method( :render,
                                                                               application_level: false)
      end
    end
  end
end