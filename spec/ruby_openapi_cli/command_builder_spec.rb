require 'spec_helper'

RSpec.describe RubyOpenapiCli::CommandBuilder do
  def operations
    [
      {
        namespace: 'bookstore', method: :get, path: '/books', operation_id: 'getBooks', path_name: 'get-books',
        path_params: [], query_params: [{ name: 'limit', required: false, type: 'integer' }],
        header_params: [{ name: 'X-API-Version', required: true }], request_body: false
      },
      {
        namespace: 'bookstore', method: :get, path: '/books/{id}', operation_id: 'getBookById', path_name: 'get-books-id',
        path_params: ['id'], query_params: [], header_params: [], request_body: false
      }
    ]
  end

  it 'builds a Thor class with a command per operation (path-based naming by default)' do
    builder = described_class.new('bookstore', operations, double('client'), double('formatter'))
    klass = builder.build_thor_class
    expect(klass.tasks.keys).to include('get_books', 'get_books_id')
    expect(klass.tasks['get_books'].options.keys.map(&:to_s)).to include('limit', 'format')
    expect(klass.tasks['get_books_id'].options.keys.map(&:to_s)).to include('id')
    expect(klass.tasks['get_books_id'].send(:required_options)).to include('id')
  end

  it 'uses operationIds for names when use_operation_ids is enabled' do
    builder = described_class.new('bookstore', operations, double('client'), double('formatter'), use_operation_ids: true)
    klass = builder.build_thor_class
    expect(klass.tasks.keys).to include('get_books', 'get_book_by_id')
  end

  it 'falls back to path-based naming when use_operation_ids is on but an operation lacks an operationId' do
    ops = operations
    ops[0][:operation_id] = nil
    builder = described_class.new('bookstore', ops, double('client'), double('formatter'), use_operation_ids: true)
    klass = builder.build_thor_class
    expect(klass.tasks.keys).to include('get_books', 'get_book_by_id')
  end

  it 'uses the configured default format when --format is absent' do
    client = double('client')
    formatter = double('formatter')
    response = double('response', status: 200, body: '{"a":1}')
    allow(client).to receive(:call).and_return(response)
    expect(formatter).to receive(:render).with('{"a":1}', :table)

    builder = described_class.new('bookstore', operations, client, formatter, default_format: :table)
    builder.build_thor_class.start(%w[get_books --x-api-version 2])
  end

  it 'sends header params to the client' do
    client = double('client')
    formatter = double('formatter')
    response = double('response', status: 200, body: '{}')
    expect(client).to receive(:call).with(
      method: :get, path: '/books', params: {},
      headers: { 'X-API-Version' => '2' }, body: nil
    ).and_return(response)
    expect(formatter).to receive(:render).with('{}', :json)

    builder = described_class.new('bookstore', operations, client, formatter, default_format: :json)
    builder.build_thor_class.start(%w[get_books --x-api-version 2])
  end
end
