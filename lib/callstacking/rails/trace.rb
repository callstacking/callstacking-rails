require "rails"
require "active_support/concern"

module Callstacking
  module Rails
    class Trace
      attr_accessor :spans, :client, :lock
      attr_reader :settings
      cattr_accessor :current_request_id

      ICON = '💥'

      def initialize(spans)
        @traces = []
        @spans  = spans
        @settings = Callstacking::Rails::Settings.new

        @lock   = Mutex.new
        @client = Callstacking::Rails::Client::Trace.new(settings.url, settings.auth_token)
      end

      def tracing
        trace_id = nil
        max_trace_entries = nil

        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          trace_id, max_trace_entries = start_request(payload[:request]&.request_id, payload[:method], payload[:controller],
                                                      payload[:action], payload[:format], ::Rails.root,
                                                      payload[:request]&.original_url || payload[:path],
                                                      payload[:headers], payload[:params])
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
                           payload[:request]&.original_url || payload[:path],
                           trace_id, @traces, max_trace_entries)
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
          traces << { type: 'TraceCallReturn',
                      order_num: order_num,
                      nesting_level: nesting_level,
                      local_variables: {},
                      args: {},
                      klass: klass_name(klass),
                      line_number: line_no,
                      path: path,
                      method_name: method_name,
                      return_value: return_value(return_val),
                      coupled_callee: coupled_callee,
                      message: nil,
          }
        end
      end

      def create_call_entry(nesting_level, order_num, klass, method_name, arguments, path, line_no, traces)
        lock.synchronize do
          traces << { type: 'TraceCallEntry',
                      order_num: order_num,
                      nesting_level: nesting_level,
                      args: arguments,
                      klass: klass_name(klass),
                      line_number: line_no,
                      path: path,
                      method_name: method_name,
                      return_value: nil,
                      coupled_callee: nil,
                      local_variables: {},
                      message: nil,
          }
        end
      end

      def create_message(message, order_num, traces)
        lock.synchronize do
          traces << { type: 'TraceMessage',
                      order_num: order_num,
                      nesting_level: 0,
                      message: message,
                      args: {},
                      klass: nil,
                      line_number: nil,
                      path: nil,
                      method_name: nil,
                      return_value: nil,
                      coupled_callee: false,
                      local_variables: {},
          }
        end
      end

      def send_traces!(trace_id, traces)
        lock.synchronize do
          return if traces.empty?

          client.upsert(trace_id, { trace_entries: traces })
          traces.clear
        end
      end
      def start_request(request_id, method, controller, action, format, path, original_url, headers, params)
        return if do_not_track_request?(original_url, format)
        
        request_id = request_id || SecureRandom.uuid
        Callstacking::Rails::Trace.current_request_id = request_id

        trace_id, _interval, max_trace_entries = client.create(method, controller, action, format,
                                                               path, original_url, request_id, headers,
                                                               params)

        print_trace_url(trace_id)

        create_message(start_request_message(method, controller, action, format),
                       spans.increment_order_num, @traces)

        return trace_id, max_trace_entries
      end

      def print_trace_url(trace_id)
        url = "#{settings.url}/traces/#{trace_id}"
        
        puts "*" * url.size
        puts url
        puts "*" * url.size

        url
      end

      def complete_request(method, controller, action, format, original_url, trace_id, traces, max_trace_entries)
        if do_not_track_request?(original_url, format)
          traces.clear
          return
        end

        create_message(completed_request_message(method, controller, action, format),
                       spans.increment_order_num, traces)

        send_traces!(trace_id, traces[0..max_trace_entries])
      end

      def track_request?(url)
        !(track_request?(url))
      end

      def do_not_track_request?(url, format)
        return true if format == "*/*"

        (url =~ /(\/assets\/|\/stylesheets\/|\/javascripts\/|\/css\/|\/js\/|\.js|\.css)/i).present?
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
