require 'rails/command'

module RubyOpenapiCli
  class RailsCommand
    # Builds a Rails::Command::Base subclass exposing one command per
    # registered API operation. bin/rails <namespace>:<underscored_operation>
    def self.build(registry)
      Class.new(Rails::Command::Base) do
        registry.each do |namespace, configuration|
          namespace(namespace.to_s)
          parser = SpecParser.new(configuration)
          client = Client.new(configuration)
          formatter = Formatter.new
          CommandBuilder.new(namespace, parser.operations, client, formatter).register_into(self)
        end
      end
    end
  end
end
