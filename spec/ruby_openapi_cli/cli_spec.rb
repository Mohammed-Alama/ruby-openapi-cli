require 'spec_helper'

RSpec.describe 'Standalone CLI integration' do
  it 'routes a command to the API and prints formatted output' do
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    stub_request(:get, 'https://api.bookstore.example/books?limit=2')
      .to_return(status: 200, body: '{"books":[{"id":1,"title":"Dune"}]}')

    custom = RubyOpenapiCli::Registry.new
    custom.register(spec_path, 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.cache_ttl = 0
    end

    klass = custom.build_thor_class
    expect { klass.start(%w[get_books --limit 2]) }
      .to output(/Dune/).to_stdout
  end
end
