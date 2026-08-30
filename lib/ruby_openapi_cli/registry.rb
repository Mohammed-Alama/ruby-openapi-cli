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
  end
end
