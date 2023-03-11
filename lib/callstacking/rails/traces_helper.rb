require 'action_view/helpers'
require "action_view/context.rb"

module Callstacking
  module Rails
    module TracesHelper
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::JavaScriptHelper
      include ActionView::Context

      def hud
        frame_url = "#{url || Callstacking::Rails::Settings::PRODUCTION_URL}/traces/#{Callstacking::Rails::Trace.current_request_id}/print"

        body = []
        body << (content_tag( :div, data: { turbo:false },
                    style: 'top: 50%; right: 10px; font-size: 24pt; :hover{text-shadow: 1px 1px 2px #000000};
                            padding: 0px; position: fixed; height: 50px; width: 40px; cursor: pointer;',
                    onclick: 'document.getElementById("callstacking-debugger").style.display = "unset";
                              document.getElementById("callstacking-close").style.display = "unset";') do
          "<span title='ctrl-d'><center>💥</center></span>".html_safe
        end)
        
        body << (content_tag(:iframe, src: frame_url, id: 'callstacking-debugger', data: { turbo:false },
                    style: "width: 50%; height: 100%; overflow: scroll; top: 20px; right: 20px; position: fixed;
                            z-index: 99; opacity: 1.0; background-color: #FFF; color: #000; border: 1px solid;
                            margin: 0; padding: 0; box-shadow: 5px 5px; display: none;") do
        end)

        body << (javascript_tag('
          document.onkeyup = function(e) {
            // Mac - option-d   Win - alt-d
            if (e.ctrlKey && e.which == 68) {
              if (document.getElementById("callstacking-debugger").style.display === "none") {
                document.getElementById("callstacking-debugger").style.display = "block";
                document.getElementById("callstacking-debugger").focus();
              } else {
                document.getElementById("callstacking-debugger").style.display = "none";
              }
            }
          };'))
        
        body.join
      end

      def inject_hud
        settings = Callstacking::Rails::Settings.new
        return unless settings.enabled?
        
        response.body = response.body.sub(/<\/body>/i, "#{hud}</body>")
      end
    end
  end
end
