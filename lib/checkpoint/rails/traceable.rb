require "active_support/concern"

module Checkpoint
  module Rails
    module Traceable
      extend ActiveSupport::Concern
      TARGET_DIV = 'traces'

      def set_trace
        client = Checkpoint::Rails::Client::Trace.new

        trace_points = {}
        params = {}
        prev_event = ''
        order_num = 0
        trace_id = nil

        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |name, start, finish, id, payload|
          next if payload[:controller] == 'Checkpoint::Rails::TracesController'

          key = request_key(payload)
          params[key] = payload[:params]

          nesting_level = -1

          trace_id, _interval = client.create(payload[:method],  payload[:controller],
                                              payload[:action],  payload[:format],
                                              ::Rails.root,      payload[:request].original_url,
                                              payload[:headers], params[key])

           message =  "Request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"

          create_message(client, message, order_num, trace_id)

          trace_points[key]&.disable
          trace_point = TracePoint.new(:call, :return) do |t|
            trace = caller[0]

            next unless trace.match?(Dir.pwd)

            order_num += 1
            caller_key = caller_key(t)

            if t.event == :call
              nesting_level += 1

              prev_event = previous_event(t)

              create_call_entry(client, nesting_level, order_num, t, trace_id)
            elsif t.event == :return
              coupled_callee = false
              coupled_callee = true if prev_event == previous_event(t)

              prev_event = previous_event(t)
              return_value = t.return_value.inspect

              create_call_return(client, coupled_callee, nesting_level, order_num, return_value, t, trace_id)

              nesting_level -= 1
            end
          end

          trace_point.enable
          trace_points[key] = trace_point
        end

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |name, start, finish, id, payload|
          trace_points[request_key(payload)]&.disable

          message =
            "Completed request: #{payload[:method]} #{payload[:controller]}##{payload[:action]} as #{payload[:format]}"

          create_message(client, message, order_num, trace_id)
        end
      end

      private

      def create_call_return(client, coupled_callee, nesting_level, order_num, return_value, t, trace_id)
        client.upsert(trace_id,
                      { traces: [{ trace_entry: { trace_entryable_type: 'TraceCallReturn',
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
                                                  } } }] })
      end

      def create_call_entry(client, nesting_level, order_num, t, trace_id)
        client.upsert(trace_id,
                      { traces: [{ trace_entry: { trace_entryable_type: 'TraceCallEntry',
                                                  order_num: order_num,
                                                  nesting_level: nesting_level,
                                                  trace_entryable_attributes: {
                                                    args: arguments_for(t),
                                                    klass: t.binding.receiver.class.name.to_s,
                                                    line_number: t.lineno,
                                                    path: t.path,
                                                    method_name: t.method_id,
                                                  } } }] })
      end

      def create_message(client, message, order_num, trace_id)
        client.upsert(trace_id,
                      { traces: [{ trace_entry: { trace_entryable_type: 'TraceMessage',
                                                  order_num: order_num,
                                                  nesting_level: 0,
                                                  trace_entryable_attributes: {
                                                    message: message
                                                  } } }] })
      end

      def caller_key(t)
        "#{t.binding.receiver.class.name.to_s}##{t.method_id}"
      end

      def request_key(payload)
        "#{payload[:controller]}##{payload[:action]}"
      end

      # def broadcast_append(partial, order_num, nesting_level, t, params)
      #   return_value = t&.return_value.inspect rescue nil
      #
      #   Turbo::StreamsChannel.broadcast_append_to(:traces,
      #                                             target: TARGET_DIV,
      #                                             partial: partial,
      #                                             locals: {
      #                                               id: SecureRandom.uuid,
      #                                               order_num: order_num,
      #                                               nesting_level: nesting_level,
      #                                               # path: caller[0].to_s,
      #                                               path: t.path,
      #                                               klass: t.binding.receiver.class.name.to_s,
      #                                               args: arguments_for(t),
      #                                               method_name: t.method_id,
      #                                               ret_val: return_value,
      #                                               line_number: t.lineno,
      #                                               local_variables: locals_for(t),
      #                                               params: params,
      #                                               template_rendered: template_rendered?(t),
      #                                               partial_rendered: partial_rendered?(t),
      #                                               layout_rendered: layout_rendered?(t),
      #                                             })
      # end
      #
      # def broadcast_message(order_num, message)
      #   Turbo::StreamsChannel.broadcast_append_to(:traces,
      #                                             target: TARGET_DIV,
      #                                             partial: 'checkpoint/rails/traces/message',
      #                                             locals: {
      #                                               order_num: order_num,
      #                                               message: message,
      #                                               color: '#6A0DAD',
      #                                             })
      # end

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
          [param, trace.binding.eval(param.to_s)]
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
