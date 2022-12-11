module Callstacking
  module Rails
    class Spans
      attr_accessor :order_num, :nesting_level
      attr_accessor :call_entry_callback, :call_return_callback

      def initialize
        @nesting_level = -1
        @order_num = -1
        @previous_entry = nil
      end

      def increment_order_num
        @order_num+=1
        @order_num
      end

      def call_entry(klass, method_name, path, line_no)
        @nesting_level+=1
        @previous_entry = previous_event(klass, method_name)
        @call_entry_callback.call(@nesting_level, increment_order_num, klass, method_name, path, line_no)
      end

      def call_return(klass, method_name, path, line_no, return_val)
        @call_return_callback.call(coupled_callee(klass, method_name), @nesting_level,
                                   increment_order_num, klass, method_name, path, line_no, return_val.inspect)
        @nesting_level-=1
      end

      def on_call_entry(&block)
        @call_entry_callback = block
      end

      def on_call_return(&block)
        @call_return_callback = block
      end

      def arguments_for(trace)
        param_names = trace&.parameters&.map(&:last)
        return {} if param_names.nil?

        param_names.map do |param|
          next if [:&, :*, :**].include?(param)
          [param, trace.binding.local_variable_get(param.to_s)]
        end.compact.to_h
      end

      def locals_for(trace)
        local_names = trace&.binding&.local_variables
        return {} if local_names.nil?

        local_names.map do |local|
          [local, trace.binding.local_variable_get(local)]
        end.to_h
      end

      private
      def previous_event(klass, method_name)
        "#{klass}:#{method_name}"
      end

      def coupled_callee(klass, method_name)
        @previous_entry == previous_event(klass, method_name)
      end
    end
  end
end
