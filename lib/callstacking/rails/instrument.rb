require 'rails'

# https://stackoverflow.com/q/52932516
module Callstacking
  module Rails
    class Instrument
      attr_accessor :spans
      attr_reader :settings, :span_modules

      def initialize
        @spans = {}
        @span_modules = Set.new
        @settings = Callstacking::Rails::Settings.new
      end

      def instrument_method(klass, method_name, application_level: true)
        method_path = (klass.instance_method(method_name).source_location.first rescue nil) ||
          (klass.method(method_name).source_location.first rescue nil)

        # method was not defined in Ruby (i.e. native)
        return if method_path.nil?

        # Application level method definitions
        return if application_level && !(method_path =~ /#{::Rails.root.to_s}/)

        return if method_path =~ /initializer/i

        tmp_module = find_or_initialize_module(klass)

        return if tmp_module.nil? ||
                    tmp_module.instance_methods.include?(method_name) ||
                    tmp_module.singleton_methods.include?(method_name)

        new_method = nil
        if RUBY_VERSION < "2.7.8"
          new_method = tmp_module.define_method(method_name) do |*args, &block|
            settings = tmp_module.instance_variable_get(:@settings)
            return super(*args, &block) if settings.disabled?
            
            method_name = __method__

            path = method(__method__).super_method.source_location.first
            line_no = method(__method__).super_method.source_location.last

            p, l = caller.find { |c| c.to_s =~ /#{::Rails.root.to_s}/}&.split(':')

            spans = tmp_module.instance_variable_get(:@spans)
            span  = spans[Thread.current.object_id]
            klass = tmp_module.instance_variable_get(:@klass)

            arguments = Callstacking::Rails::Instrument.arguments_for(method(__method__).super_method, args)

            span.call_entry(klass, method_name, arguments, p || path, l || line_no)
            return_val = super(*args, &block)
            span.call_return(klass, method_name, p || path, l || line_no, return_val)

            return_val
          end
          new_method.ruby2_keywords if new_method.respond_to?(:ruby2_keywords)
        else
          new_method = tmp_module.define_method(method_name) do |*args, **kwargs, &block|
            settings = tmp_module.instance_variable_get(:@settings)
            return super(*args, **kwargs, &block) if settings.disabled?

            method_name = __method__

            path = method(__method__).super_method.source_location.first
            line_no = method(__method__).super_method.source_location.last

            p, l = caller.find { |c| c.to_s =~ /#{::Rails.root.to_s}/}&.split(':')

            spans = tmp_module.instance_variable_get(:@spans)
            span  = spans[Thread.current.object_id]
            klass = tmp_module.instance_variable_get(:@klass)

            arguments = Callstacking::Rails::Instrument.arguments_for(method(__method__).super_method, args)

            span.call_entry(klass, method_name, arguments, p || path, l || line_no)
            return_val = super(*args, **kwargs, &block)
            span.call_return(klass, method_name, p || path, l || line_no, return_val)

            return_val
          end

        end

        new_method
      end

      def enable!(klasses)
        Array.wrap(klasses).each do |klass|
          instrument_klass(klass, application_level: true)
        end
      end

      def disable!(modules = span_modules)
        modules.each do |mod|
          mod.instance_methods.each do |method_name|
            mod.remove_method(method_name)
          end
        end
        
        reset!
      end

      def instrumentation_required?
        span_modules.empty?
      end

      def reset!
        span_modules.clear
      end

      def instrument_klass(klass, application_level: true)
        relevant_methods = all_methods(klass) - filtered
        relevant_methods.each { |method| instrument_method(klass, method, application_level: application_level) }
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

      def add_span(span)
        spans[Thread.current.object_id] ||= span
      end

      private
      def find_or_initialize_module(klass)
        name = klass&.name rescue nil
        return if name.nil?

        module_name = "#{klass.name.gsub('::', '')}Span"
        module_index = klass.ancestors.map(&:to_s).index(module_name)

        unless module_index
          # Development class reload -
          #   ancestors are reset but module definition remains
          new_module = Object.const_get(module_name) rescue nil
          new_module||=Object.const_set(module_name, Module.new)
          span_modules << new_module

          new_module.instance_variable_set("@klass", klass)
          new_module.instance_variable_set("@spans", spans)
          new_module.instance_variable_set("@settings", settings)

          klass.prepend new_module
          klass.singleton_class.prepend new_module if klass.class == Module

          return find_or_initialize_module(klass)
        end

        span_modules << klass.ancestors[module_index]
        klass.ancestors[module_index]
      end

      def all_methods(klass)
        (klass.instance_methods +
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
