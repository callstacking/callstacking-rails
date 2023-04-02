require "callstacking/rails/client/base"

module Callstacking
  module Rails
    module Client
      class Trace < Base
        CREATE_URL = "/api/v1/traces.json"
        UPDATE_URL = "/api/v1/traces/:id.json"

        def initialize(url, auth_token)
          super

          # All requests for trace and trace entry creation are async
          #   join by the client side generated tuid
          @async = true
        end

        def create(request_id, tuid, method_name, klass, action_name, format_name, root_path, url, headers, params)
          post(CREATE_URL,
               {},
               {
                 request_id: request_id,
                 tuid: tuid,
                 method_name: method_name,
                 klass: klass,
                 action_name: action_name,
                 format_name: format_name,
                 root_path: root_path,
                 url: url,
                 h: headers.to_h,
                 p: params.to_h,
               })

          nil
        end

        def upsert(trace_id, traces)
          patch(UPDATE_URL.gsub(':id', trace_id), {}, traces)
        end
      end
    end
  end
end
