# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# License::   MIT
#
# Details::   Maps transformations to internal Class methods.
#
#             Stores :
#               substitutions
#               over rides
#               prefixes
#               postfixes
#
# These are keyed on the associated method binding operator, which is
# essentially the method call/active record column on the class.
#
# Clients can decide exactly how these can be applied to incoming data.
#
# Usage::
#
#   Provides a singleton instance of Transformations::Factory
#   so you can specify additional transforms in .rb config as follows :
#
# IN : my_transformations.rb
#
#     DataShift::Transformer.factory do |factory|
#        factory.set_default_on(Project, 'value_as_string', 'default text' )
#     end
#
#   This global factory is automatically utilised by the default Populator
#   during data load.
#
#   If passed an optional locale, rules for other
#   languages can be specified. If not specified, defaults to <tt>:en</tt>.
#
require 'thread_safe'

# Helper class
Struct.new('Substitution', :pattern, :replacement)

module DataShift

  module Transformer

    extend self

    # Yields a singleton instance of Transformations::Factory
    # so you can specify additional transforms in .rb config
    # If passed an optional locale, rules for other
    # languages can be specified. If not specified, defaults to <tt>:en</tt>.
    #
    # Only rules for English are provided.
    #
    def factory(locale = :en)
      if block_given?
        yield Factory.instance(locale)
      else
        Factory.instance(locale)
      end
    end

    class Factory

      include DataShift::Logging

      @__instance__ = ThreadSafe::Cache.new

      def self.instance(locale = :en)
        @__instance__[locale] ||= new
      end

      def self.reset(locale = :en)
        @__instance__[locale] = new
      end

      attr_reader :defaults, :overrides, :substitutions
      attr_reader :prefixes, :postfixes

      def initialize
        clear
      end

      def clear
        @defaults = new_hash_instance
        @overrides = new_hash_instance
        @substitutions = new_hash_instance
        @prefixes = new_hash_instance
        @postfixes = new_hash_instance
      end

      # Default values and over rides per class can be provided in YAML config file.
      #
      def configure_from(load_object_class, yaml_file, locale_key = nil)

        data = YAML.load( ERB.new(IO.read(yaml_file)).result )

        class_name = load_object_class.name

        data = data[locale_key] if(locale_key)

        configure_from_yaml(load_object_class, data[class_name]) if(data[class_name])
      end

      def configure_from_yaml(load_object_class, yaml)

        method_map = {
          defaults: :set_default_on,
          overrides: :set_override_on,
          substitutions: :set_substitution_on_list,
          prefixes: :set_prefix_on,
          postfixes: :set_postfix_on
        }

        puts("Configuring Transforms for load_object_class [#{load_object_class}]")

        method_map.each do |key, call|
          settings = yaml[key.to_s]

          settings.each do |operator, value|
            puts("Configuring Transform [#{key}] for [#{operator.inspect}] to [#{value}]")
            logger.info("Configuring Transform [#{key}] for [#{operator.inspect}] to [#{value}]")
            send( call, load_object_class, operator, value)
          end if(settings && settings.is_a?(Hash))
        end

      end

      def hash_key(key)
        key.is_a?(MethodBinding) ? key.klass.name : key
      end
      
      # DEFAULTS

      def set_default_on(class_name, operator, default_value )
        # puts "In set_default_on ", klass, operator, default_value
        defaults_for(class_name)[operator] = default_value
      end

      def defaults_for( class_name )
        defaults[hash_key(class_name)] ||= new_hash_instance
      end

      def default( method_binding )
        defaults_for(hash_key(method_binding))[method_binding.operator]
      end

      def default?(class_name, operator)
        defaults_for(hash_key(class_name)).key?(operator)
      end

      def has_default?( method_binding )
        defaults_for(hash_key(method_binding)).key?(method_binding.operator)
      end

      # SUBSTITUTIONS

      def substitutions_for( class_name )
        substitutions[hash_key(class_name)] ||= new_hash_instance
      end

      def substitution( method_binding )
        substitutions_for( hash_key(method_binding))[method_binding.operator]
      end

      def has_substitution?( method_binding )
        substitution_for( hash_key(method_binding)).key?(method_binding.operator)
      end

      # OVER RIDES
      def overrides_for(class_name)
        overrides[hash_key(class_name)] ||= new_hash_instance
      end

      def override( method_binding )
        overrides_for( hash_key(method_binding))[method_binding.operator]
      end

      def has_override?( method_binding )
        overrides_for( hash_key(method_binding)).key?(method_binding.operator)
      end

      def prefixes_for(class_name)
        prefixes[hash_key(class_name)] ||= new_hash_instance
      end

      def prefix( method_binding )
        prefixes_for( hash_key(method_binding))[method_binding.operator]
      end

      def has_prefix?( method_binding )
        prefixes_for( hash_key(method_binding)).key?(method_binding.operator)
      end

      def postfixes_for(class_name)
        postfixes[hash_key(class_name)] ||= new_hash_instance
      end

      def postfix( method_binding )
        postfixes_for( hash_key(method_binding))[method_binding.operator]
      end

      def has_postfix?( method_binding )
        postfixes_for( hash_key(method_binding)).key?(method_binding.operator)
      end

      # use when no inbound data supplied
      def set_default(method_binding, default_value )
        defaults_for( hash_key(method_binding))[method_binding.operator] = default_value
      end

      # use regardless of whether inbound data supplied
      def set_override( method_binding, value )
        overrides_for( hash_key(method_binding))[method_binding.operator] = value
      end

      def set_substitution( method_binding, rule, replacement )
        substitutions_for( hash_key(method_binding))[method_binding.operator] =
          Struct::Substitution.new(rule, replacement)
      end

      def set_prefix( method_binding, value)
        prefixes_for( hash_key(method_binding))[method_binding.operator] = value
      end

      def set_postfix( method_binding, value)
        postfixes_for( hash_key(method_binding))[method_binding.operator] = value
      end

      # Class based versions



      # use regardless of whether inbound data supplied
      def set_override_on(klass, operator, value )
        overrides_for(klass)[operator] = value
      end

      def set_substitution_on(klass, operator, rule, replacement )
        substitutions_for(klass)[operator] = Struct::Substitution.new(rule, replacement)
      end

      def set_prefix_on(klass, operator, value)
        prefixes_for(klass)[operator] = value
      end

      def set_postfix_on(klass, operator, value)
        postfixes_for(klass)[operator] = value
      end

      private

      def set_substitution_on_list(klass, operator, list )
        substitutions_for(hash_key(klass))[operator] = Struct::Substitution.new(list[0], list[1])
      end

      def new_hash_instance
        ActiveSupport::HashWithIndifferentAccess.new {}
      end

    end

  end ## class

end
