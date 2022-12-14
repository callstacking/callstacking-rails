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
        def instrument_method(klass, method_name, application_level: true)
          tmp_module = find_or_initialize_module(klass)
          return if tmp_module.instance_methods.include?(method_name) ||
                      tmp_module.singleton_methods.include?(method_name)

          m = (klass.instance_method(method_name).source_location.first rescue nil) ||
                (klass.method(method_name).source_location.first rescue nil)

          # Application level method definitions
          return unless m =~ /#{::Rails.root.to_s}/ if application_level

          tmp_module.define_method(method_name) do |*args, &block|
            klass = self.class
            method_name = __method__

            path = method(__method__).super_method.source_location.first
            line_no = method(__method__).super_method.source_location.last

            p,l = caller.find{|c| c.to_s =~ /#{::Rails.root.to_s}/}&.split(':')

            puts "  method = #{method_name}"

            @@spans.call_entry(klass, method_name, p || path, l || line_no)
            return_val = super(*args, &block)
            @@spans.call_return(klass, method_name, p || path, l || line_no, return_val)
            
            return_val
          end
        end

        def find_or_initialize_module(klass)
          module_name = "#{name.gsub('::', '')}Span"
          module_index = ancestors.map(&:to_s).index(module_name)

          unless module_index
            new_module = Object.const_set(module_name, Module.new)
            
            prepend new_module
            klass.singleton_class.prepend new_module if klass.class == Module
            
            return find_or_initialize_module(klass)
          end

          ancestors[module_index]
        end

        def init(klass)
          methods = (klass.instance_methods +
                     klass.private_instance_methods(false) +
                     klass.protected_instance_methods(false) +
                     klass.methods +
                     klass.singleton_methods).uniq

          @filtered||=(Object.instance_methods + Object.private_instance_methods +
                         Object.protected_instance_methods + Object.methods(false)).uniq

          relevant = methods - @filtered
          relevant.each { |method| instrument_method(klass, method) }
        end
      end
    end
  end
end
