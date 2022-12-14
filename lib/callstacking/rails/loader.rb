require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :loader, :root, :once
      def initialize
        @root =  Regexp.new(::Rails.root.to_s)
      end

      def on_load
        trace = TracePoint.new(:end) do |tp|
          klass = tp.self
          path  = tp.path

          if path =~ root
            klass.include(Callstacking::Rails::Span)
            klass.init(klass)
          end
        end

        trace.enable

        instrument_method(ActionView::PartialRenderer, :render)
        instrument_method(ActionView::TemplateRenderer, :render)
      end

      def instrument_method(klass, method)
        return if klass.ancestors.map(&:to_s).index("Callstacking::Rails::Span")
        
        klass.include(Callstacking::Rails::Span)
        klass.instrument_method(klass, method, application_level: false)
      end
    end
  end
end