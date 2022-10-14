require "checkpoint/rails/traceable"
require "checkpoint/rails/setup"
require "checkpoint/rails/settings"
require "checkpoint/rails/client/base"
require "checkpoint/rails/client/authenticate"
require "checkpoint/rails/client/trace"
require "checkpoint/rails/traces_helper"

module Checkpoint
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Checkpoint::Rails

      include ::Checkpoint::Rails::Traceable

      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      initializer 'local_helper.action_controller' do
        ActiveSupport.on_load :action_controller do
          helper Checkpoint::Rails::TracesHelper
          include Checkpoint::Rails::TracesHelper
        end
      end

      initializer :append_before_action do
        ActionController::Base.send :after_action, :inject_hud
      end

      set_trace
    end
  end
end
