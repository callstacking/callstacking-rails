require "action_view/helpers/tag_helper"
require "action_view/context.rb"

module Callstacking
  module Rails
    module TracesHelper
      include ActionView::Helpers::TagHelper
      include ActionView::Context
      include Callstacking::Rails::Settings

      def hud
        read_settings

        frame_url = "#{url || Callstacking::Rails::Settings::PRODUCTION_URL}/traces/#{Callstacking::Rails::Trace.current_request_id}/print"

        body = []
        body << (content_tag( :div, data: { turbo:false },
                    style: 'background-color: #FFF; font-size: 20pt; top: 50%; right: 10px; font-size: 36pt;
                            padding: 0px; position: fixed; height: 50px; width: 40px; cursor: pointer;',
                    onclick: 'document.getElementById("callstacking-debugger").style.display = "unset";
                              document.getElementById("callstacking-close").style.display = "unset";') do
          "<<"
        end)
        
        body << (content_tag(:iframe, src: frame_url, id: 'callstacking-debugger', data: { turbo:false },
                    style: "width: 50%; height: 100%; overflow: scroll; top: 20px; right: 20px; position: fixed;
                            z-index: 99; opacity: 1.0; background-color: #FFF; color: #000; border: 1px solid;
                            margin: 0; padding: 0; box-shadow: 5px 5px; display: none;") do
        end)
        
        body.join
      end

      def inject_hud
        response.body = response.body.sub(/<\/body>/i, "#{hud}</body>")
      end
    end
  end
end