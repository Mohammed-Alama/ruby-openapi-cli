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
      headers: { 'X-API-Version' => '2' }, body: nil, body_type: nil
    ).and_return(response)
    expect(formatter).to receive(:render).with('{}', :json)

    builder = described_class.new('bookstore', operations, client, formatter, default_format: :json)
    builder.build_thor_class.start(%w[get_books --x-api-version 2])
  end

  describe 'request body via --field and --input' do
    def body_operations
      [
        {
          namespace: 'bookstore', method: :post, path: '/books', operation_id: 'createBook', path_name: 'post-books',
          path_params: [], query_params: [], header_params: [],
          request_body: true, request_body_media_types: ['application/json']
        }
      ]
    end

    def build(media_types = ['application/json'])
      ops = body_operations
      ops[0][:request_body_media_types] = media_types
      client = double('client')
      formatter = double('formatter')
      response = double('response', status: 201, body: '{"id":1}')
      allow(client).to receive(:call).and_return(response)
      allow(formatter).to receive(:render).and_return('{"id":1}')
      builder = described_class.new('bookstore', ops, client, formatter, default_format: :json)
      [builder, client, formatter]
    end

    it 'adds --field and --input options to a command that accepts a body' do
      builder, = build
      opts = builder.build_thor_class.tasks['post_books'].options.keys.map(&:to_s)
      expect(opts).to include('field', 'input')
    end

    it 'sends --field values as a JSON object for a json spec body' do
      builder, client, = build
      expect(client).to receive(:call).with(
        method: :post, path: '/books', params: {}, headers: {},
        body: { 'title' => 'Dune', 'year' => '1965' }, body_type: :json
      )
      builder.build_thor_class.start(%w[post_books --field title=Dune --field year=1965])
    end

    it 'sends a raw --input JSON body' do
      builder, client, = build
      expect(client).to receive(:call).with(
        method: :post, path: '/books', params: {}, headers: {},
        body: '{"title":"Dune"}', body_type: :json
      )
      builder.build_thor_class.start(['post_books', '--input', '{"title":"Dune"}'])
    end

    it 'sends --field values as a form when the spec declares urlencoded' do
      builder, client, = build(['application/x-www-form-urlencoded'])
      expect(client).to receive(:call).with(
        method: :post, path: '/books', params: {}, headers: {},
        body: { 'title' => 'Dune' }, body_type: :form
      )
      builder.build_thor_class.start(%w[post_books --field title=Dune])
    end

    it 'flags the body as multipart when a --field value starts with @' do
      builder, client, = build
      expect(client).to receive(:call).with(
        method: :post, path: '/books', params: {}, headers: {},
        body: { 'cover' => '@/tmp/cover.jpg' }, body_type: :multipart
      )
      builder.build_thor_class.start(%w[post_books --field cover=@/tmp/cover.jpg])
    end

    it 'errors when both --field and --input are provided' do
      builder, client, = build
      expect(client).not_to receive(:call)
      expect { builder.build_thor_class.start(%w[post_books --field title=Dune --input '{}']) }
        .to raise_error(SystemExit)
    end
  end
end
