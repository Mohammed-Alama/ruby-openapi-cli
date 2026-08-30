require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'mime/types'

module RubyOpenapiCli
  class Client
    def initialize(configuration)
      @configuration = configuration
    end

    def call(method:, path:, params: {}, body: nil, body_type: nil, headers: {})
      connection.public_send(method, path) do |req|
        req.headers.merge!(default_headers.merge(headers))
        case body_type
        when :form
          req.body = body
          req.headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
        when :multipart
          req.body = multipart_body(body)
        else
          if body
            req.body = body.is_a?(String) ? body : JSON.generate(body)
            req.headers['Content-Type'] ||= 'application/json'
          elsif !params.empty?
            req.params = params
          end
        end
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: @configuration.base_url) do |faraday|
        faraday.request :multipart
        faraday.request :url_encoded
        faraday.request :retry, max: 2, interval: 0.05
        faraday.adapter Faraday.default_adapter
      end
    end

    # Converts a field hash to a multipart payload. Field values prefixed with
    # "@" are treated as file uploads and wrapped in a Faraday::UploadIO.
    def multipart_body(fields)
      return fields unless fields.is_a?(Hash)

      fields.each_with_object({}) do |(key, value), out|
        out[key] = value.to_s.start_with?('@') ? uploadio(value.to_s) : value
      end
    end

    def uploadio(value)
      path = value.sub(/\A@/, '')
      Faraday::UploadIO.new(path, mime_for(path))
    end

    def mime_for(path)
      MIME::Types.type_for(path).first&.content_type || 'application/octet-stream'
    end

    def default_headers
      return {} unless @configuration.auth_token

      { 'Authorization' => "Bearer #{@configuration.auth_token}" }
    end
  end
end
