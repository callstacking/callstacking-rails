# Configure Rails Environment
require 'callstacking/rails/settings'
require 'callstacking/rails/env'
require 'callstacking/rails/client/base'
require 'callstacking/rails/client/authenticate'

ENV["RAILS_ENV"] = "test"

# https://github.com/Shopify/minitest-silence
ENV["CI"] = "true"

Callstacking::Rails::Settings.new.save('test@test.com',
                                       'testing123',
                                       Callstacking::Rails::Settings::PRODUCTION_URL)

ENV[Callstacking::Rails::Settings::ENV_KEY] = 'true'


require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

def module_and_method_exist?(module_name, method_name)
  Object.const_defined?(module_name.to_sym) &&
    module_name.constantize.method_defined?(method_name.to_sym)
end

require 'mocha/minitest'