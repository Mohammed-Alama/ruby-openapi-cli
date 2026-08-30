require 'openapi3_parser'
require 'open-uri'
require 'tmpdir'
require 'digest'
require 'fileutils'
require 'json'

module RubyOpenapiCli
  class SpecLoadError < StandardError; end

  class SpecParser
    def initialize(configuration)
      @configuration = configuration
    end

    def document
      @document ||= Openapi3Parser.load(fetch)
    rescue StandardError => e
      raise SpecLoadError, "Failed to load OpenAPI spec: #{e.message}"
    end

    def operations
      document.paths.flat_map do |path_item_name, path_item|
        path_item.map do |method_name, operation|
          next unless HttpVerbs.include?(method_name.to_sym)
          next unless operation

          build_operation(method_name, path_item_name, operation)
        end.compact
      end
    end

    private

    HttpVerbs = %i[get post put patch delete head options].freeze

    def fetch
      remote? ? fetch_remote : File.read(@configuration.spec_url)
    end

    def remote?
      @configuration.spec_url =~ %r{\Ahttps?://}
    end

    def cache_dir
      File.join(Dir.tmpdir, 'ruby_openapi_cli')
    end

    def cache_path
      File.join(cache_dir, "#{Digest::SHA256.hexdigest(@configuration.spec_url)}.json")
    end

    def cache_fresh?
      return false unless File.exist?(cache_path)
      File.mtime(cache_path) > Time.now - @configuration.cache_ttl
    end

    def fetch_remote
      return File.read(cache_path) if cache_fresh?

      body = URI.open(@configuration.spec_url).read
      FileUtils.mkdir_p(cache_dir)
      File.write(cache_path, body)
      body
    end

    def build_operation(method_name, path, operation)
      params = operation.parameters || []
      path_params = params.select { |p| p.in == 'path' }.map(&:name)
      query_params = params.select { |p| p.in == 'query' }.map do |p|
        { name: p.name, required: !!param_required(p), type: (p.schema&.type || 'string') }
      end
      header_params = params.select { |p| p.in == 'header' }.map do |p|
        { name: p.name, required: !!param_required(p) }
      end

      {
        namespace: @configuration.namespace,
        method: method_name.to_sym,
        path: path,
        operation_id: operation.operation_id || "#{method_name}-#{slugify(path)}",
        path_params: path_params,
        query_params: query_params,
        header_params: header_params,
        request_body: !operation.request_body.nil?
      }
    end

    def param_required(param)
      param.to_h['required']
    end

    def slugify(path)
      path.gsub(/[{}]/, '').tr('/', '-')
    end
  end
end
