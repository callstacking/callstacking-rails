module Callstacking
  module Rails
    module Helpers
      module InstrumentHelper
        extend ActiveSupport::Concern
        def callstacking_setup
          if params[:debug] == '1'
            Callstacking::Rails::Engine.start_tracing
          end

          yield
        ensure
          Callstacking::Rails::Engine.stop_tracing if params[:debug] == '1'
        end
      end
    end
  end
end