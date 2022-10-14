require 'json'

module Checkpoint
  module Rails
    module Client
      class Error < StandardError; end

      class Authenticate < Base
        URL = "/api/v1/auth.json"

        def login(email, password)
          resp = post(URL, email: email, password: password)

          raise Faraday::UnauthorizedError if resp&.body.nil?

          body = resp&.body || {}
          body["token"]
        end
      end
    end
  end
end
