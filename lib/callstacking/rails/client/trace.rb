require "callstacking/rails/client/base"
require "async"
require "async/http/internet"
require "json"

module Callstacking
  module Rails
    module Client
      class Trace < Base
        CREATE_URL = "/api/v1/traces.json"
        UPDATE_URL = "/api/v1/traces/:id.json"

        def create(method_name, klass, action_name, format_name, root_path, url, request_id, headers, params)
          Async do
            internet = Async::HTTP::Internet.new
            headers = {}
            body = JSON.dump({ method_name: method_name,
                          klass: klass,
                          action_name: action_name,
                          format_name: format_name,
                          root_path: root_path,
                          url: url,
                          request_id: request_id,
                          h: headers.to_h,
                          p: params.to_h,
                        })
            resp = internet.post(CREATE_URL, headers, body)

            if resp.status == 200
              return resp.body["trace_id"], resp.body["pulse_interval"], resp.body["max_trace_entries"]
            end
          
          ensure 
            internet&.close
          end

          nil
        end

        def upsert(trace_id, traces)
          resp = patch(UPDATE_URL.gsub(':id', trace_id), {}, traces)

          resp.status
        end
      end
    end
  end
end
