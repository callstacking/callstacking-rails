module Checkpoint
  module Rails
    class Engine < ::Rails::Engine
      include ::Checkpoint::Rails::Traceable

      isolate_namespace Checkpoint::Rails
      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      initializer 'local_helper.action_controller' do
        ActiveSupport.on_load :action_controller do
          helper Checkpoint::Rails::TracesHelper
        end
      end

      set_trace
    end
  end
end
