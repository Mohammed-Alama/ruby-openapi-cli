module RubyOpenapiCli
  class Configuration
    attr_accessor :spec_url, :base_url, :auth_token, :cache_ttl, :default_format, :use_operation_ids

    def initialize(spec_url, namespace)
      @spec_url = spec_url
      @namespace = namespace
      @cache_ttl = 300
      @default_format = :json
      @use_operation_ids = false
      yield self if block_given?
    end

    def namespace
      @namespace
    end
  end
end
