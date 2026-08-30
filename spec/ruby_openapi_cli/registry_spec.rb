require 'spec_helper'

RSpec.describe RubyOpenapiCli::Registry do
  it 'registers an api under a namespace' do
    registry = described_class.new
    registry.register('https://api.example.com/openapi.yaml', 'bookstore') do |c|
      c.base_url = 'https://api.example.com'
    end
    expect(registry.namespaces).to eq([:bookstore])
    expect(registry[:bookstore].spec_url).to eq('https://api.example.com/openapi.yaml')
  end

  it 'exposes a shared module-level registry' do
    expect(RubyOpenapiCli.registry).to be(RubyOpenapiCli.registry)
  end
end
