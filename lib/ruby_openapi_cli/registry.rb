require 'ruby_openapi_cli/spec_parser'
require 'ruby_openapi_cli/client'
require 'ruby_openapi_cli/formatter'
require 'ruby_openapi_cli/command_builder'

module RubyOpenapiCli
  class Registry
    def initialize
      @apis = {}
    end

    def register(spec_url, namespace, &block)
      key = namespace.to_sym
      @apis[key] = Configuration.new(spec_url, key.to_s, &block)
      self
    end

    def each(&block)
      @apis.each(&block)
    end

    def [](namespace)
      @apis[namespace]
    end

    def namespaces
      @apis.keys
    end

    def start(argv)
      build_thor_class.start(argv)
    end

    def build_thor_class
      klass = Class.new(Thor)
      each do |namespace, configuration|
        parser = SpecParser.new(configuration)
        client = Client.new(configuration)
        formatter = Formatter.new
        CommandBuilder.new(namespace, parser.operations, client, formatter,
          default_format: configuration.default_format,
          use_operation_ids: configuration.use_operation_ids).register_into(klass)
      end
      klass
    end
  end
end
