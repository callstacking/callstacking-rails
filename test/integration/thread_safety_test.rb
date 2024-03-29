require "test_helper"

# CALLSTACKING_API_TOKEN required for these integration tests. Full end-to-end.
# https://github.com/callstacking/callstacking-rails/settings/secrets/actions
class ThreadSafetyTest < ActionDispatch::IntegrationTest
  TEST_URL = "http://www.example.com"
  MAX_RETRIES = 50

  # Test initiates multiple http requests and makes multiple method calls in parallel for each of the requests.
  #   The results are validated against the Call Stacking server, ensuring that none of
  #   the trace values are intermixed.
  test "concurrent tracing" do
    ::Callstacking::Rails::Trace.trace_log_clear
    
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

    ::Callstacking::Rails::Trace.trace_log.each do |trace_id, url|
      params   = url.gsub(TEST_URL, '')

      # Retry until the trace is available.
      retry_count = 0
      json = {'trace_entries' => []}
      while json['trace_entries'].empty? && retry_count <= MAX_RETRIES
        response = client.show(trace_id)
        json     = response.body

        sleep 1
        retry_count+=1
      end

      ::Callstacking::Rails::Logger.log "url: #{url} -- json: #{json.inspect}"
      
      sleep 10

      entry_classes  = json['trace_entries'].find_all do |trace_entry|
        urls.values.include?(trace_entry['klass'])
      end

      entry_classes.each do |trace_entry|
        assert_equal urls[params], trace_entry['klass']
      end
    end
  end
end
