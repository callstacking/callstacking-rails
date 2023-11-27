module Callstacking
  module Rails
    class Spans
      attr_accessor :order_num, :nesting_level, :previous_entry
      attr_accessor :call_entry_callback, :call_return_callback

      def initialize
        reset
      end

      def increment_order_num
        @order_num+=1
        @order_num
      end

      def increment_nesting_level
        @nesting_level+=1
        @nesting_level
      end

      def call_entry(klass, method_name, arguments, path, line_no, method_source)
        @nesting_level+=1
        @previous_entry = previous_event(klass, method_name)
        @call_entry_callback.call(@nesting_level, increment_order_num, klass, method_name, arguments, path, line_no, method_source)
      end

      def call_return(klass, method_name, path, line_no, return_val, method_source)
        @call_return_callback.call(coupled_callee(klass, method_name), @nesting_level,
                                   increment_order_num, klass, method_name, path, line_no, return_val, method_source)
        @nesting_level-=1
      end

      def on_call_entry(&block)
        @call_entry_callback = block
      end

      def on_call_return(&block)
        @call_return_callback = block
      end

      def reset
        @nesting_level = -1
        @order_num = -1
        @previous_entry = nil
      end

      private
      def previous_event(klass, method_name)
        "#{klass}:#{method_name}"
      end

      def coupled_callee(klass, method_name)
        previous_entry == previous_event(klass, method_name)
      end
    end
  end
end
