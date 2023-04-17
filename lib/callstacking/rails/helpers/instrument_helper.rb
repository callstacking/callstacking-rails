module Callstacking
  module Rails
    module Helpers
      module InstrumentHelper
        extend ActiveSupport::Concern
        def callstacking_setup
          Callstacking::Rails::Engine.start_tracing(self)

          yield
        ensure
          Callstacking::Rails::Engine.stop_tracing(self)
        end
      end
    end
  end
end