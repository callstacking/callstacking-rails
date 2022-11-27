require "active_support/concern"
require "rails"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/settings"

module Callstacking
  module Rails
    module Traceable
      extend ActiveSupport::Concern
      include Callstacking::Rails::Settings

      TARGET_DIV = 'traces'

      mattr_accessor :current_request_id

      def set_trace
        read_settings
        
        client = Callstacking::Rails::Client::Trace.new

        trace_points = {}
        params       = {}
        prev_event   = ''
        order_num    = 0
        trace_id     = nil
        traces       = []
        lock         = Mutex.new
        task         = nil

        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          next if payload[:controller] == 'Callstacking::Rails::TracesController'

          key = request_key(payload)
          params[key] = payload[:params]

          nesting_level = -1

          request_id = payload[:request].request_id
          Callstacking::Rails::Traceable.current_request_id = request_id

          trace_id, _interval = client.create(payload[:method],  payload[:controller],
                                              payload[:action],  payload[:format],
                                              ::Rails.root,      payload[:request].original_url,
                                              request_id, 
                                              payload[:headers], params[key])


          puts "#{settings[:url] || Callstacking::Rails::Settings::PRODUCTION_URL}/traces/#{trace_id}"

          task = Concurrent::TimerTask.new(execution_interval: 1, timeout_interval: 60) {
            send_traces!(trace_id, traces, lock, client)
          }

          task.execute

          create_message(start_request_message(payload), order_num, traces, lock)

          trace_points[key]&.disable

          trace_point = TracePoint.new(:call, :return) do |t|
            trace = caller[0]

            next unless trace.match?(Dir.pwd)

            order_num += 1

            if t.event == :call
              nesting_level += 1

              prev_event = previous_event(t)

              create_call_entry(nesting_level, order_num, t, traces, lock)
            elsif t.event == :return
              coupled_callee = false
              coupled_callee = true if prev_event == previous_event(t)

              prev_event = previous_event(t)
              return_value = t.return_value.inspect

              create_call_return(coupled_callee, nesting_level, order_num, return_value, t, traces, lock)

              nesting_level -= 1
            end
          end

          trace_point.enable
          trace_points[key] = trace_point
        end

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |name, start, finish, id, payload|
          trace_points[request_key(payload)]&.disable
          task&.shutdown

          create_message(completed_request_message(payload), order_num, traces, lock)
          send_traces!(trace_id, traces, lock, client)
        end
      end

      private

      def completed_request_message(payload)
        "Completed request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"
      end

      def start_request_message(payload)
        puts "start request message - "
        "Request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"
      end

      def create_call_return(coupled_callee, nesting_level, order_num, return_value, t, traces, lock)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallReturn',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       local_variables: locals_for(t),
                                       klass: t.binding.receiver.class.name.to_s,
                                       line_number: t.lineno,
                                       path: t.path,
                                       method_name: t.method_id,
                                       return_value: return_value,
                                       coupled_callee: coupled_callee,
                                     } } }
        end
      end

      def create_call_entry(nesting_level, order_num, t, traces, lock)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceCallEntry',
                                     order_num: order_num,
                                     nesting_level: nesting_level,
                                     trace_entryable_attributes: {
                                       args: arguments_for(t),
                                       klass: t.binding.receiver.class.name.to_s,
                                       line_number: t.lineno,
                                       path: t.path,
                                       method_name: t.method_id,
                                     } } }
        end
      end

      def create_message(message, order_num, traces, lock)
        lock.synchronize do
          traces << { trace_entry: { trace_entryable_type: 'TraceMessage',
                                     order_num: order_num,
                                     nesting_level: 0,
                                     trace_entryable_attributes: {
                                       message: message
                                     } } }
        end
      end

      def send_traces!(trace_id, traces, lock, client)
        lock.synchronize do
          return if traces.empty?

          client.upsert(trace_id, { traces: traces })
          traces.clear
        end
      end

      def caller_key(t)
        "#{t.binding.receiver.class.name.to_s}##{t.method_id}"
      end

      def request_key(payload)
        "#{payload[:controller]}##{payload[:action]}"
      end

      def previous_event(t)
        "#{t.binding.receiver.class.name.to_s}:#{t.method_id}"
      end

      def view_rendered?(t)
        t.path.to_s =~ /view/
      end

      def partial_rendered?(t)
        view_rendered?(t) && Pathname.new(t.path).basename.to_s =~ /^_/
      end

      def layout_rendered?(t)
        view_rendered?(t) && t.path =~ /layouts/
      end

      def template_rendered?(t)
        view_rendered?(t) && !partial_rendered?(t) && !layout_rendered?(t)
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
    end
  end
end
