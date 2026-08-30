module RubyOpenapiCli
  class Configuration
    attr_accessor :spec_url, :base_url, :auth_token, :cache_ttl, :default_format

    def initialize(spec_url, namespace)
      @spec_url = spec_url
      @namespace = namespace
      @cache_ttl = 300
      @default_format = :json
      yield self if block_given?
    end

    def namespace
      @namespace
    end
  end
end
