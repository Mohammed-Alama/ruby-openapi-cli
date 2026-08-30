require 'thor'

module RubyOpenapiCli
  class CommandBuilder
    def initialize(namespace, operations, client, formatter, default_format: :json, use_operation_ids: false)
      @namespace = namespace
      @operations = operations
      @client = client
      @formatter = formatter
      @default_format = default_format
      @use_operation_ids = use_operation_ids
    end

    def build_thor_class
      klass = Class.new(Thor)
      klass.namespace(@namespace)
      klass.desc("#{@namespace} commands", "Run `ruby-openapi-cli #{@namespace}` for this API's commands")
      register_into(klass)
      klass
    end

    def register_into(klass)
      @operations.each { |op| register_operation(klass, op) }
    end

    private

    def register_operation(klass, op)
      source = @use_operation_ids && op[:operation_id] ? op[:operation_id] : op[:path_name]
      name = underscore(source)
      accepts_body = op[:request_body]
      signature = op[:path_params].map { |p| "[--#{underscore(p)}]" }
      signature << '[--field key=value]' if accepts_body
      signature << '[--input JSON]' if accepts_body

      klass.desc("#{name} #{signature.join(' ')}", "#{op[:method].to_s.upcase} #{op[:path]}")

      op[:path_params].each do |param|
        klass.method_option underscore(param), type: :string, required: true, desc: "path param #{param}"
      end
      op[:query_params].each do |param|
        klass.method_option underscore(param[:name]), type: option_type(param[:type]), required: !!param[:required], desc: "query param #{param[:name]}"
      end
      op[:header_params].each do |param|
        klass.method_option underscore(param[:name]), type: :string, required: !!param[:required], desc: "header param #{param[:name]}"
      end
      if accepts_body
        klass.method_option :field, type: :string, repeatable: true, desc: 'Send a form field (repeatable), e.g. --field title=Dune'
        klass.method_option :input, type: :string, desc: 'Send a raw JSON request body'
      end
      klass.method_option :format, type: :string, default: '', desc: 'output format: json|yaml|table'

      client = @client
      formatter = @formatter
      default_format = @default_format
      body_media_types = op[:request_body_media_types] || []
      path_opts = op[:path_params].map { |p| [p, underscore(p)] }.to_h
      query_opts = op[:query_params].map { |param| [underscore(param[:name]), param[:name]] }.to_h
      header_opts = op[:header_params].map { |param| [underscore(param[:name]), param[:name]] }.to_h
      klass.send(:define_method, name) do |*args|
        path = op[:path]
        path_opts.each do |param, opt_name|
          val = options[opt_name]
          path = path.gsub("{#{param}}", val.to_s) if val
        end
        params = {}
        query_opts.each do |opt_name, param_name|
          val = options[opt_name]
          params[param_name] = val if val
        end
        headers = {}
        header_opts.each do |opt_name, param_name|
          val = options[opt_name]
          headers[param_name] = val if val
        end

        body = nil
        body_type = nil
        if accepts_body
          field_hash = (options[:field] || []).each_with_object({}) do |kv, h|
            key, _, value = kv.partition('=')
            h[key] = value
          end
          input = options[:input]

          if !field_hash.empty? && input
            say('Cannot use both --field and --input', :red)
            exit 1
          end

          if !field_hash.empty?
            body = field_hash
            body_type = if field_hash.any? { |_, v| v.to_s.start_with?('@') }
                          :multipart
                        elsif body_media_types.include?('application/x-www-form-urlencoded')
                          :form
                        else
                          :json
                        end
          elsif input
            body = input
            body_type = :json
          end
        end

        fmt = options[:format]
        fmt = fmt.empty? ? nil : fmt.to_sym

        response = client.call(
          method: op[:method],
          path: path,
          params: params,
          headers: headers,
          body: body,
          body_type: body_type
        )

        output = formatter.render(response.body, fmt || default_format)
        if (200..299).cover?(response.status)
          say(output)
        else
          say("\n[#{response.status}] #{output}", :red)
          exit 1
        end
      end
    end

    def underscore(name)
      name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.gsub(/-/, '_')
    end

    def option_type(type)
      { 'integer' => :numeric, 'boolean' => :boolean, 'array' => :array }[type] || :string
    end
  end
end
