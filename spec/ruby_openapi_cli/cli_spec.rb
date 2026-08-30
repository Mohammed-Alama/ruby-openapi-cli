require 'spec_helper'

RSpec.describe 'Standalone CLI integration' do
  def spec_path
    File.expand_path('../fixtures/bookstore.yaml', __dir__)
  end

  it 'routes a command to the API and prints formatted output' do
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

  it 'uses path-based command names by default' do
    registry = RubyOpenapiCli::Registry.new
    registry.register(spec_path, 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.cache_ttl = 0
    end
    expect(registry.build_thor_class.tasks.keys).to include('get_books', 'get_books_id')
  end

  it 'uses operationId-based command names when use_operation_ids is enabled' do
    registry = RubyOpenapiCli::Registry.new
    registry.register(spec_path, 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.cache_ttl = 0
      c.use_operation_ids = true
    end
    expect(registry.build_thor_class.tasks.keys).to include('get_books', 'get_book_by_id')
  end
end
