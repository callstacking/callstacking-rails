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
      end
    end
  end
end