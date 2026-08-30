require 'spec_helper'

RSpec.describe RubyOpenapiCli::SpecParser do
  def make_config(spec_url)
    RubyOpenapiCli::Configuration.new(spec_url, 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.cache_ttl = 0
    end
  end

  it 'parses a local spec file into operations' do
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    parser = described_class.new(make_config(spec_path))
    ops = parser.operations

    expect(ops.map { |o| o[:operation_id] }).to contain_exactly('getBooks', 'createBook', 'getBookById')

    get_books = ops.find { |o| o[:operation_id] == 'getBooks' }
    expect(get_books[:method]).to eq(:get)
    expect(get_books[:path]).to eq('/books')
    expect(get_books[:query_params].map { |p| p[:name] }).to contain_exactly('limit', 'q')

    get_by_id = ops.find { |o| o[:operation_id] == 'getBookById' }
    expect(get_by_id[:path_params]).to eq(['id'])
  end

  it 'computes path-based command names, disambiguating colliding paths' do
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    parser = described_class.new(make_config(spec_path))
    ops = parser.operations
    names = ops.to_h { |o| ["#{o[:method]} #{o[:path]}", o[:path_name]] }
    expect(names).to eq('get /books' => 'get-books', 'post /books' => 'post-books', 'get /books/{id}' => 'get-books-id')
  end

  it 'keeps operation_id as the raw spec value (nil when absent)' do
    spec = <<~YAML
      openapi: 3.0.3
      info: { title: T, version: 1.0.0 }
      paths:
        /things:
          get:
            responses:
              '200': { description: ok }
    YAML
    path = File.join(Dir.tmpdir, "noopid-#{rand(1000)}.yaml")
    File.write(path, spec)
    parser = described_class.new(make_config(path))
    op = parser.operations.first
    expect(op[:operation_id]).to be_nil
    expect(op[:path_name]).to eq('get-things')
    FileUtils.rm_f(path)
  end

  it 'fetches and parses a remote spec over HTTP' do
    body = File.read(File.expand_path('../fixtures/bookstore.yaml', __dir__))
    stub_request(:get, 'https://api.example.com/openapi.yaml').to_return(status: 200, body: body)
    config = make_config('https://api.example.com/openapi.yaml')
    ops = RubyOpenapiCli::SpecParser.new(config).operations
    expect(ops.length).to eq(3)
  end

  it 'raises SpecLoadError on an unreachable spec' do
    stub_request(:get, 'https://api.example.com/missing.yaml').to_return(status: 404, body: 'nope')
    config = make_config('https://api.example.com/missing.yaml')
    expect { RubyOpenapiCli::SpecParser.new(config).operations }
      .to raise_error(RubyOpenapiCli::SpecLoadError)
  end

  it 'caches a remote spec and reuses it within the ttl without re-fetching' do
    FileUtils.rm_rf(File.join(Dir.tmpdir, 'ruby_openapi_cli'))
    body = File.read(File.expand_path('../fixtures/bookstore.yaml', __dir__))
    stub_request(:get, 'https://api.example.com/cached.yaml').to_return(status: 200, body: body)
    config = RubyOpenapiCli::Configuration.new('https://api.example.com/cached.yaml', 'bookstore') do |c|
      c.base_url = 'https://api.example.com'
      c.cache_ttl = 60
      c.auth_token = nil
    end
    parser = described_class.new(config)
    expect(parser.operations.length).to eq(3)

    # Second parse within ttl must not hit the network again; the cache
    # guarantees only one fetch total across both parses.
    described_class.new(config).operations
    expect(a_request(:get, 'https://api.example.com/cached.yaml')).to have_been_made.once
  end
end
