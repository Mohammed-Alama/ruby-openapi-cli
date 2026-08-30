require 'faraday'
require 'faraday/retry'

module RubyOpenapiCli
  class Client
    def initialize(configuration)
      @configuration = configuration
    end

    def call(method:, path:, params: {}, body: nil, headers: {})
      connection.public_send(method, path) do |req|
        req.headers.merge!(default_headers.merge(headers))
        if body
          req.body = body.is_a?(String) ? body : JSON.generate(body)
          req.headers['Content-Type'] ||= 'application/json'
        elsif !params.empty?
          req.params = params
        end
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: @configuration.base_url) do |faraday|
        faraday.request :retry, max: 2, interval: 0.05
        faraday.adapter Faraday.default_adapter
      end
    end

    def default_headers
      return {} unless @configuration.auth_token

      { 'Authorization' => "Bearer #{@configuration.auth_token}" }
    end
  end
end
