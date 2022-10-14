require "checkpoint/rails/version"
require "checkpoint/rails/traceable"
require "checkpoint/rails/setup"
require "checkpoint/rails/settings"
require "checkpoint/rails/client/base"
require "checkpoint/rails/client/authenticate"
require "checkpoint/rails/client/trace"

module Checkpoint
  module Rails
    mattr_accessor :environment

    @@environment = (ENV['RAILS_ENV'] || Checkpoint::Rails::Settings::DEFAULT_ENVIRONMENT).parameterize(separator: '_').to_sym
  end
end

require "checkpoint/rails/engine"
