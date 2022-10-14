module Checkpoint
  module Rails
    module TracesHelper
      COLORS = %w[#FF9AA2 #FFB7B2 #FFDAC1 #E2F0CB #B5EAD7 #C7CEEA]
      OUTPUT_BUFFER = :output_buffer

      def color_mapping(level)
        COLORS[level % COLORS.size]
      end

      def show_local(local_variables, beg_marker: '(', end_marker: ')', label: '')
        return nil if local_variables.empty?

        locals = local_variables.reject { |a, _v| a == OUTPUT_BUFFER }.collect { |a, v|
          "<span class=\"text-green-800\">#{a}</span>:<span class=\"text-red-800 pl-1 pr-1\"><i>
         #{truncate(v.inspect, length: 60, omission: '..')}</i></span>".html_safe
        }

        "#{label}#{beg_marker}#{locals.join(', ').html_safe}#{end_marker}".html_safe
      end

      def nesting(nesting_level)
        content_tag :div, class: "pl-#{nesting_level * 8} flex-none bg-white" do
        end
      end

      def show_order_num(order_num)
        content_tag :div, class: "bg-white flex-none w-8" do
          "#{order_num}"
        end
      end

      def show_path(p, line_number)
        content_tag :div, class: "invisible group-hover:visible grow text-right text-slate-600" do
          "#{Pathname.new(p).relative_path_from(::Rails.root)}:#{line_number}"
        end
      end

      def hud
        content_tag :div, id: :traces, class: "",
                    style: "width: 50%; height: 50%; top: 0; right: 0;
                            z-index: 10; opacity: 0.5; background-color: #FFF; color: #000;"  do
          turbo_stream_from :traces
        end
      end
    end
  end
end
