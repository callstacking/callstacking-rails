require "rails"
require "active_support/concern"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/settings"

module Callstacking
  module Rails
    class Trace
      include Callstacking::Rails::Settings

      attr_accessor :spans, :client, :lock
      cattr_accessor :current_request_id

      def initialize(spans)
        @traces = []
        @spans  = spans

        @lock   = Mutex.new
        @client = Callstacking::Rails::Client::Trace.new
      end

      def tracing
        read_settings

        trace_id = nil
        max_trace_entries = nil

        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          trace_id, max_trace_entries = start_request(payload[:request]&.request_id, payload[:method], payload[:controller],
                                                       payload[:action], payload[:format], ::Rails.root,
                                                       payload[:original_url], payload[:headers], payload[:params])
        end

        @spans.on_call_entry do |nesting_level, order_num, klass, method_name, arguments, path, line_no|
          create_call_entry(nesting_level, order_num, klass, method_name, arguments, path, line_no, @traces)
        end

        @spans.on_call_return do |coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val|
          create_call_return(coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, @traces)
        end

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |name, start, finish, id, payload|
          complete_request(payload[:method], payload[:controller],
                           payload[:action], payload[:format],
                           trace_id, max_trace_entries)
        end
      end

      private

      def completed_request_message(method, controller, action, format)
        "Completed request: #{method} #{controller}##{action} as #{format}"
      end

      def start_request_message(method, controller, action, format)
        "Started request: #{method} #{controller}##{action} as #{format}"
      end

      def create_call_return(coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, traces)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallReturn',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       local_variables: {},
                                       klass: klass_name(klass),
                                       line_number: line_no,
                                       path: path,
                                       method_name: method_name,
                                       return_value: return_value(return_val),
                                       coupled_callee: coupled_callee,
                                     } } }
        end
      end

      def create_call_entry(nesting_level, order_num, klass, method_name, arguments, path, line_no, traces)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallEntry',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       args: arguments,
                                       klass: klass_name(klass),
                                       line_number: line_no,
                                       path: path,
                                       method_name: method_name,
                                     } } }
        end
      end

      def create_message(message, order_num, traces)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceMessage',
                                     order_num: order_num,
                                     nesting_level: 0,
                                     trace_entryable_attributes: {
                                       message: message
                                     } } }
        end
      end

      def send_traces!(trace_id, traces)
        lock.synchronize do
          return if traces.empty?

          client.upsert(trace_id, { traces: traces })
          traces.clear
        end
      end
      def start_request(request_id, method, controller, action, format, path, original_url, headers, params)
        request_id = request_id || SecureRandom.uuid
        Callstacking::Rails::Trace.current_request_id = request_id

        trace_id, _interval, max_trace_entries = client.create(method, controller, action, format,
                                                               path, original_url, request_id, headers,
                                                               params)

        puts "#{settings[:url] || Callstacking::Rails::Settings::PRODUCTION_URL}/traces/#{trace_id}"

        create_message(start_request_message(method, controller, action, format),
                       spans.increment_order_num, @traces)

        return trace_id, max_trace_entries
      end

      def complete_request(method, controller, action, format, trace_id, max_trace_entries)
        create_message(completed_request_message(method, controller, action, format),
                       spans.increment_order_num, @traces)
        send_traces!(trace_id, @traces[0..max_trace_entries])
      end

      def return_value(return_val)
        return_val.inspect
      rescue ThreadError
        # deadlock; recursive locking (ThreadError)
        # Discourse overrides ActiveSupport::Inflector methods via lib/freedom_patches/inflector_backport.rb
        # when return_value.inspect is called, it triggers a subsequent call
        # to the instrumented inflector method, causing another call to mutex#synchronize
        # from the block of the first synchronize call

        return_val.to_s rescue "****"  # Can't evaluate
      end

      def klass_name(klass)
        (klass.is_a?(Class) ? klass.name : klass.class.name)
      end
    end
  end
end
