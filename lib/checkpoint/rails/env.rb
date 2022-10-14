module Checkpoint
  module Rails
    class Env
      DEFAULT_ENVIRONMENT = "development"

      cattr_accessor :environment

      @@environment = (ENV['RAILS_ENV'] || DEFAULT_ENVIRONMENT).parameterize(separator: '_').to_sym

      def self.production?
        @@environment == DEFAULT_ENVIRONMENT.parameterize(separator: '_').to_sym
      end
    end
  end
end
