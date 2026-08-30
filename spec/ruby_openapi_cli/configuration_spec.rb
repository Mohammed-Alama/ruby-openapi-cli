require 'spec_helper'

RSpec.describe RubyOpenapiCli::Configuration do
  it 'has sensible defaults' do
    config = described_class.new('https://api.example.com/openapi.yaml', 'api')
    expect(config.spec_url).to eq('https://api.example.com/openapi.yaml')
    expect(config.base_url).to be_nil
    expect(config.cache_ttl).to eq(300)
    expect(config.default_format).to eq(:json)
    expect(config.use_operation_ids).to be(false)
  end

  it 'allows setting attributes in a block' do
    config = described_class.new('spec', 'api') do |c|
      c.base_url = 'https://api.example.com'
      c.auth_token = 'sekret'
      c.cache_ttl = 600
      c.default_format = :table
    end
    expect(config.base_url).to eq('https://api.example.com')
    expect(config.auth_token).to eq('sekret')
    expect(config.cache_ttl).to eq(600)
    expect(config.default_format).to eq(:table)
  end
end
