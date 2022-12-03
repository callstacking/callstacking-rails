require 'rails'

# https://stackoverflow.com/q/52932516
module Callstacking
  module Rails
    module Span
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        mattr_accessor :spans
        def add_method(method_name, klass)
          tmp_module = find_or_initialize_module
          return if tmp_module.instance_methods(false).include?(method_name)

          tmp_module.define_method(method_name) do |*args, &block|
            klass = self.class.to_s
            method_name = __method__

            path = method(__method__).super_method.source_location.first
            line_no = method(__method__).super_method.source_location.last

            p,l = caller.find{|c| c.to_s =~ /#{::Rails.root.to_s}/}&.split(':')

            @@spans.call_entry(klass, method_name, p || path, l || line_no)
            return_val = super(*args, &block)
            @@spans.call_return(klass, method_name, p || path, l || line_no, return_val)
            return_val
          end
        end

        def find_or_initialize_module
          module_name = "#{name.gsub('::', '')}Span"
          module_index = ancestors.map(&:to_s).index(module_name)

          unless module_index
            prepend Object.const_set(module_name, Module.new)
            return find_or_initialize_module
          end

          ancestors[module_index]
        end

        def init(k)
          # No need to init Modules - they'll get included in classes
          #  and those classes can be wrapped.
          return if k.class == Module

          methods = (k.instance_methods(false) + k.private_instance_methods(false) + k.protected_instance_methods(false) + k.methods(false)).uniq
          @filtered||=(Object.instance_methods + Object.private_instance_methods + Object.protected_instance_methods + Object.methods(false)).uniq

          relevant = methods - @filtered

          relevant.each do |r|
            add_method(r, k)
          end
        end
      end
    end
  end
end
