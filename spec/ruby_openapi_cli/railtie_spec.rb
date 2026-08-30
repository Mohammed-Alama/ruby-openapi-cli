require 'spec_helper'
require 'rails'
require 'ruby_openapi_cli/railtie'
require 'ruby_openapi_cli/rails_command'

RSpec.describe RubyOpenapiCli::RailsCommand do
  it 'registers a command class for each namespace' do
    registry = RubyOpenapiCli::Registry.new
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    registry.register(spec_path, 'bookstore') { |c| c.base_url = 'https://api.example.com'; c.cache_ttl = 0 }

    klass = RubyOpenapiCli::RailsCommand.build(registry)
    expect(klass).to be_a(Class)
    expect(klass < Rails::Command::Base).to be(true)
  end
end
