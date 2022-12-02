require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :loader, :root
      def initialize
        @loader = ::Rails.autoloaders.main
        @root =  Regexp.new(::Rails.root.to_s)
      end

      def on_load
        loader.on_load do |cpath, value, abspath|
          if abspath =~ root
            klass = cpath.constantize
            klass.include(Callstacking::Rails::Span)
            klass.init(klass)
          end
        end
      end
    end
  end
end