module RubyOpenapiCli
  class Railtie < ::Rails::Railtie
    initializer 'ruby_openapi_cli.commands' do
      require_relative 'rails_command'
    end
  end
end
