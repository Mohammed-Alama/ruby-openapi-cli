require 'thor'

module RubyOpenapiCli
  class CommandBuilder
    def initialize(namespace, operations, client, formatter)
      @namespace = namespace
      @operations = operations
      @client = client
      @formatter = formatter
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
      name = op[:operation_id].gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.gsub(/-/, '_')
      accepts_body = op[:request_body]
      signature = op[:path_params].map { |p| "[--#{underscore(p)}]" } + (accepts_body ? ['[BODY]'] : [])

      klass.desc("#{name} #{signature.join(' ')}", "#{op[:method].to_s.upcase} #{op[:path]}")

      op[:path_params].each do |param|
        klass.method_option underscore(param), type: :string, required: true, desc: "path param #{param}"
      end
      op[:query_params].each do |param|
        klass.method_option underscore(param[:name]), type: option_type(param[:type]), required: !!param[:required], desc: "query param #{param[:name]}"
      end
      klass.method_option :format, type: :string, default: '', desc: 'output format: json|yaml|table'

      client = @client
      formatter = @formatter
      path_opts = op[:path_params].map { |p| [p, underscore(p)] }.to_h
      query_opts = op[:query_params].map { |param| [underscore(param[:name]), param[:name]] }.to_h
      klass.send(:define_method, name) do |*args|
        path = op[:path]
        body_arg = accepts_body ? args.pop : nil
        path_opts.each do |param, opt_name|
          val = options[opt_name]
          path = path.gsub("{#{param}}", val.to_s) if val
        end
        params = {}
        query_opts.each do |opt_name, param_name|
          val = options[opt_name]
          params[param_name] = val if val
        end
        fmt = options[:format]
        fmt = fmt.empty? ? nil : fmt.to_sym

        response = client.call(
          method: op[:method],
          path: path,
          params: params,
          body: body_arg && !body_arg.empty? ? body_arg : nil
        )

        output = formatter.render(response.body, fmt || :json)
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
