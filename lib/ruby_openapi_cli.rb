require 'ruby_openapi_cli/version'
require 'ruby_openapi_cli/configuration'
require 'ruby_openapi_cli/registry'
require 'ruby_openapi_cli/spec_parser'
require 'ruby_openapi_cli/client'

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
