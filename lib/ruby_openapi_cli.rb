require 'ruby_openapi_cli/version'
require 'ruby_openapi_cli/configuration'
require 'ruby_openapi_cli/registry'
require 'ruby_openapi_cli/spec_parser'
require 'ruby_openapi_cli/client'
require 'ruby_openapi_cli/formatter'
require 'ruby_openapi_cli/command_builder'
require 'ruby_openapi_cli/cli'

module RubyOpenapiCli
  class << self
    def registry
      @registry ||= Registry.new
    end

    def register(spec_url, namespace, &block)
      registry.register(spec_url, namespace, &block)
    end

    def setup
      yield SetupProxy.new(registry)
    end

    class SetupProxy
      def initialize(registry)
        @registry = registry
      end

      def register(spec_url, namespace, &block)
        @registry.register(spec_url, namespace, &block)
      end
    end
  end
end
