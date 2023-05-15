require "test_helper"
require "callstacking/rails/logger"

# CALLSTACKING_API_TOKEN required for these integration tests. Full end-to-end.
# https://github.com/callstacking/callstacking-rails/settings/secrets/actions
class ThreadSafetyTest < ActionDispatch::IntegrationTest
  TEST_URL = "http://www.example.com"

  test "concurrent tracing" do
    urls      = {'/hello?debug=1'   => 'English',
                 '/bounjor?debug=1' => 'French',
                 '/hallo?debug=1'   => 'German'}

    settings  = Callstacking::Rails::Settings.new
    client    = Callstacking::Rails::Client::Trace.new(settings.url, settings.auth_token)
    client.async = false # Since we'll already be running in a thread

    threads = urls.keys.collect do |url|
      Thread.new do
        get url
      end
    end
    threads.each(&:join)

    urls.each do |url, klass|
      response = client.show('xxxx', url: "#{TEST_URL}#{url}")
      json     = response.body

      sleep 20

      Logger.log("url: #{url} -- json: #{json.inspect}")

      json['trace_entries'][1..10].each do |trace_entry|
        assert_equal klass, trace_entry['klass']
      end
    end
  end
end
