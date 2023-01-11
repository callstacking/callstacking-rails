require 'rails'

# https://stackoverflow.com/q/52932516
module Callstacking
  module Rails
    class Instrument
      attr_accessor :spans, :klass
      attr_reader :root

      def initialize(spans, klass)
        @spans = spans
        @klass = klass
        @root  = Regexp.new(::Rails.root.to_s)
      end

      def instrument_method(method_name, application_level: true)
        method_path = (klass.instance_method(method_name).source_location.first rescue nil) ||
          (klass.method(method_name).source_location.first rescue nil)

        # Application level method definitions
        return unless method_path =~ root if application_level

        tmp_module = find_or_initialize_module

        return if tmp_module.nil? ||
                    tmp_module.instance_methods.include?(method_name) ||
                    tmp_module.singleton_methods.include?(method_name)

        tmp_module.define_method(method_name) do |*args, **kwargs, &block|
          method_name = __method__

          path = method(__method__).super_method.source_location.first
          line_no = method(__method__).super_method.source_location.last

          p, l = caller.find { |c| c.to_s =~ /#{::Rails.root.to_s}/}&.split(':')

          spans = tmp_module.instance_variable_get(:@spans)
          klass = tmp_module.instance_variable_get(:@klass)

          arguments = Callstacking::Rails::Instrument.arguments_for(method(__method__).super_method, args)

          spans.call_entry(klass, method_name, arguments, p || path, l || line_no)
          return_val = super(*args, **kwargs, &block)
          spans.call_return(klass, method_name, p || path, l || line_no, return_val)

          return_val
        end
      end

      def find_or_initialize_module
        return if klass&.name == nil

        module_name = "#{klass.name.gsub('::', '')}Span"
        module_index = klass.ancestors.map(&:to_s).index(module_name)

        unless module_index
          new_module = Object.const_set(module_name, Module.new)

          new_module.instance_variable_set("@klass", klass)
          new_module.instance_variable_set("@spans", spans)

          klass.prepend new_module
          klass.singleton_class.prepend new_module if klass.class == Module

          return find_or_initialize_module
        end

        klass.ancestors[module_index]
      end

      def instrument_klass(application_level: true)
        relevant = all_methods - filtered
        relevant.each { |method| instrument_method(method, application_level: application_level) }
      end

      def self.arguments_for(m, args)
        param_names = m.parameters&.map(&:last)
        return {} if param_names.nil?

        h = param_names.map.with_index do |param, index|
          next if [:&, :*, :**].include?(param)
          [param, args[index]]
        end.compact.to_h

        filter = ::Rails.application.config.filter_parameters
        f = ActiveSupport::ParameterFilter.new filter
        f.filter h
      end

      private

      def all_methods
        @all_methods ||= (klass.instance_methods +
          klass.private_instance_methods(false) +
          klass.protected_instance_methods(false) +
          klass.methods +
          klass.singleton_methods).uniq
      end

      def filtered
        @filtered ||= (Object.instance_methods + Object.private_instance_methods +
          Object.protected_instance_methods + Object.methods(false)).uniq
      end

    end
  end
end
