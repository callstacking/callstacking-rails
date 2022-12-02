require "rails"
require "active_support/concern"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/settings"
require "callstacking/rails/span"

module Callstacking
  module Rails
    class Trace
      include Callstacking::Rails::Settings

      attr_accessor :spans, :client, :lock
      cattr_accessor :current_request_id

      def initialize(spans)
        @traces = []
        @lock = Mutex.new
        @spans = spans
        @client = Callstacking::Rails::Client::Trace.new
      end

      def tracing
        read_settings

        task = nil
        trace_id = nil

        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          next if payload[:controller] == 'Callstacking::Rails::TracesController'

          request_id = payload[:request].request_id
          Callstacking::Rails::Trace.current_request_id = request_id

          trace_id, _interval = client.create(payload[:method], payload[:controller],
                                              payload[:action], payload[:format],
                                              ::Rails.root, payload[:request].original_url,
                                              request_id, payload[:headers],
                                              payload[:params])

          puts "#{settings[:url] || Callstacking::Rails::Settings::PRODUCTION_URL}/traces/#{trace_id}"

          task = Concurrent::TimerTask.new(execution_interval: 1, timeout_interval: 60) {
            send_traces!(trace_id, @traces)
          }

          task.execute

          create_message(start_request_message(payload), spans.increment_order_num, @traces)
        end

        @spans.on_call_entry do |nesting_level, order_num, klass, method_name, path, line_no|
          create_call_entry(nesting_level, order_num, klass, method_name, path, line_no, @traces)
        end

        @spans.on_call_return do |coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val|
          create_call_return(coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, @traces)
        end

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |name, start, finish, id, payload|
          task&.shutdown

          create_message(completed_request_message(payload), spans.increment_order_num, @traces)
          send_traces!(trace_id, @traces)
        end
      end

      private

      def completed_request_message(payload)
        "Completed request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"
      end

      def start_request_message(payload)
        "Request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"
      end

      def create_call_return(coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, traces)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallReturn',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       local_variables: {},
                                       klass: klass,
                                       line_number: line_no,
                                       path: path,
                                       method_name: method_name,
                                       return_value: return_val,
                                       coupled_callee: coupled_callee,
                                     } } }
        end
      end

      def create_call_entry(nesting_level, order_num, klass, method_name, path, line_no, traces)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallEntry',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       #args: arguments_for(t),
                                       klass: klass,
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
    end
  end
end
