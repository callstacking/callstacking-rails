module Callstacking
  module Rails
    module Helpers
      module InstrumentHelper
        extend ActiveSupport::Concern
        def callstacking_setup
          exception = nil
          @last_callstacking_sample = TIme.utc.now
          Callstacking::Rails::Engine.start_tracing(self)

          yield
        rescue Exception => e
          @last_callstacking_exception = Time.utc.now
          exception = e
          raise e
        ensure
          Callstacking::Rails::Engine.stop_tracing(self, exception)
        end
      end

      def callstcking_sample_trace?
        if @last_callstacking_exception.present? && @last_callstacking_exception < 1.minute.ago
          @last_callstacking_exception = nil
          return true
        end

        false
      end

      def callstacking_followup_exception_trace?
        if @last_callstacking_sample.present? && @last_callstacking_sample < 1.hour.ago
          @last_callstacking_exception = nil
          return true
        end

        false
      end
    end
  end
end