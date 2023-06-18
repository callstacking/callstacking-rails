module Callstacking
  module Rails
    module Helpers
      module InstrumentHelper
        extend ActiveSupport::Concern
        def callstacking_setup
          exception = nil
          Callstacking::Rails::Engine.start_tracing(self)

          yield
        rescue Exception => e
          exception = e
          raise e
        ensure
          Callstacking::Rails::Engine.stop_tracing(self, exception)
        end
      end
    end
  end
end