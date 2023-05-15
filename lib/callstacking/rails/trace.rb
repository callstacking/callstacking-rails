require "rails"
require 'active_support/core_ext/object/deep_dup'
require "callstacking/rails/helpers/heads_up_display_helper"

module Callstacking
  module Rails
    class Trace
      include Callstacking::Rails::Helpers::HeadsUpDisplayHelper
      
      attr_accessor :spans, :client, :lock, :traces
      attr_reader :settings
      cattr_accessor :current_trace_id
      cattr_accessor :current_tuid
      cattr_accessor :trace_log

      ICON = '💥'
      MAX_TRACE_ENTRIES = 3000
      
      @@trace_log||={}

      def initialize(spans)

        @traces    = []
        @spans     = spans
        @settings  = Callstacking::Rails::Settings.new

        @lock     = Mutex.new
        @client   = Callstacking::Rails::Client::Trace.new(settings.url, settings.auth_token)

        init_uuids(nil, nil)
        init_callbacks(nil)
      end

      def begin_trace(controller)
        @trace_id, @tuid = init_uuids(controller.request&.request_id || SecureRandom.uuid, TimeBasedUUID.generate)
        trace_log[@trace_id] = controller.request&.original_url
        
        init_callbacks(@tuid)

        start_request(@trace_id, @tuid,
                      controller.action_name, controller.controller_name,
                      controller.action_name, controller.request.format, ::Rails.root.to_s,
                      controller.request&.original_url,
                      controller.request.headers, controller.request.params, @traces)
      end

      def end_trace(controller)
        return if @trace_id.nil? || @tuid.nil?
        
        complete_request(@trace_id, @tuid,
                         controller.action_name, controller.controller_name,
                         controller.action_name, controller.request.format,
                         controller.request&.original_url,
                         @traces, MAX_TRACE_ENTRIES)

        inject_hud(@settings, controller.request, controller.response)
      end

      def self.trace_log_clear
        trace_log.clear
      end

      private

      def init_callbacks(tuid)
        @spans.on_call_entry do |nesting_level, order_num, klass, method_name, arguments, path, line_no|
          create_call_entry(tuid, nesting_level, order_num, klass, method_name, arguments, path, line_no, @traces)
        end

        @spans.on_call_return do |coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val|
          create_call_return(tuid, coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, @traces)
        end
      end

      def init_uuids(trace_id, tuid)
        Callstacking::Rails::Trace.current_trace_id = trace_id
        Callstacking::Rails::Trace.current_tuid = tuid

        return trace_id, tuid
      end

      def completed_request_message(method, controller, action, format)
        "Completed request: #{method} #{controller}##{action} as #{format}"
      end

      def start_request_message(method, controller, action, format)
        "Started request: #{method} #{controller}##{action} as #{format}"
      end

      def create_call_return(tuid, coupled_callee, nesting_level, order_num, klass, method_name, path, line_no, return_val, traces)
        lock.synchronize do
          traces << { tuid: tuid,
                      type: 'TraceCallReturn',
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

      def create_call_entry(tuid, nesting_level, order_num, klass, method_name, arguments, path, line_no, traces)
        lock.synchronize do
          traces << { tuid: tuid,
                      type: 'TraceCallEntry',
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

      def create_message(tuid, message, order_num, traces)
        lock.synchronize do
          traces << { tuid: tuid,
                      type: 'TraceMessage',
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

          STDERR.puts "Sending #{traces.size} traces to Callstacking.io -- enabled? - #{settings.enabled?} -- #{traces.inspect}"

          client.upsert(trace_id,
                        { trace_entries: traces.deep_dup })
          traces.clear
        end
      end
      def start_request(trace_id, tuid, method, controller, action, format, path, original_url, headers, params, traces)
        lock.synchronize do
          traces.clear
        end

        return if do_not_track_request?(original_url, format)

        client.create(trace_id, tuid,
                      method, controller,
                      action, format,
                      path, original_url,
                      headers, params)

        print_trace_url(trace_id)

        create_message(tuid, start_request_message(method, controller, action, format),
                       spans.increment_order_num, @traces)
      end

      def print_trace_url(trace_id)
        url = "#{settings.url}/traces/#{trace_id}"
        
        puts "*" * url.size
        puts url
        puts "*" * url.size

        url
      end

      def complete_request(trace_id, tuid, method, controller, action, format, original_url, traces, max_trace_entries)
        return if do_not_track_request?(original_url, format)

        create_message(tuid, completed_request_message(method, controller, action, format),
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
