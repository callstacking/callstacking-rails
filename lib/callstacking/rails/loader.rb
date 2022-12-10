require "rails"

module Callstacking
  module Rails
    class Loader
      attr_accessor :loader, :root, :once
      def initialize
        @loader = ::Rails.autoloaders.main
        @once   = ::Rails.autoloaders.once
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

        # ::Rails.autoloaders.log!
        # loader.on_load do |cpath, value, abspath|
        #   puts "cpath = #{cpath} - #{abspath}"
        #
        #   if abspath =~ root
        #     klass = cpath.constantize
        #     klass.include(Callstacking::Rails::Span)
        #     klass.init(klass)
        #   end
        # end
        
        # @once.on_load do |cpath, value, abspath|
        #   puts "cpath2 = #{cpath} - #{abspath}"
        #
        #   if abspath =~ root
        #     klass = cpath.constantize
        #     klass.include(Callstacking::Rails::Span)
        #     klass.init(klass)
        #   end
        # end
      end
    end
  end
end