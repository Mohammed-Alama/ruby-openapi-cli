require 'spec_helper'

RSpec.describe RubyOpenapiCli::CommandBuilder do
  def operations
    [
      {
        namespace: 'bookstore', method: :get, path: '/books', operation_id: 'getBooks',
        path_params: [], query_params: [{ name: 'limit', required: false, type: 'integer' }],
        header_params: [], request_body: false
      },
      {
        namespace: 'bookstore', method: :get, path: '/books/{id}', operation_id: 'getBookById',
        path_params: ['id'], query_params: [], header_params: [], request_body: false
      }
    ]
  end

  it 'builds a Thor class with a command per operation' do
    builder = described_class.new('bookstore', operations, double('client'), double('formatter'))
    klass = builder.build_thor_class
    expect(klass.tasks.keys).to include('get_books', 'get_book_by_id')
    expect(klass.tasks['get_books'].options.keys.map(&:to_s)).to include('limit', 'format')
    expect(klass.tasks['get_book_by_id'].options.keys.map(&:to_s)).to include('id')
    expect(klass.tasks['get_book_by_id'].send(:required_options)).to include('id')
  end
end
