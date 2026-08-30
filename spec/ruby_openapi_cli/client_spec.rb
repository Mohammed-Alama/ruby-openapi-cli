require 'spec_helper'

RSpec.describe RubyOpenapiCli::Client do
  def make_config(auth_token: nil)
    RubyOpenapiCli::Configuration.new('spec.yaml', 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.auth_token = auth_token
    end
  end

  it 'fires a GET with query params' do
    stub_request(:get, 'https://api.bookstore.example/books?limit=2')
      .to_return(status: 200, body: '{"ok":true}', headers: { 'Content-Type' => 'application/json' })
    client = described_class.new(make_config)
    response = client.call(method: :get, path: '/books', params: { 'limit' => 2 })
    expect(response.status).to eq(200)
    expect(response.body).to eq('{"ok":true}')
  end

  it 'sends a JSON body on POST' do
    stub_request(:post, 'https://api.bookstore.example/books')
      .with(body: '{"title":"Dune"}')
      .to_return(status: 201, body: '{"id":1}')
    client = described_class.new(make_config)
    response = client.call(method: :post, path: '/books', body: { 'title' => 'Dune' })
    expect(response.status).to eq(201)
  end

  it 'adds a bearer token header when configured' do
    stub_request(:get, 'https://api.bookstore.example/books')
      .with(headers: { 'Authorization' => 'Bearer sekret' })
      .to_return(status: 200, body: '[]')
    client = described_class.new(make_config(auth_token: 'sekret'))
    expect(client.call(method: :get, path: '/books').status).to eq(200)
  end

  it 'sends a form-urlencoded body when body_type is :form' do
    stub_request(:post, 'https://api.bookstore.example/books')
      .with(body: 'title=Dune')
      .to_return(status: 201, body: '{"id":1}')
    client = described_class.new(make_config)
    expect(client.call(method: :post, path: '/books', body: { 'title' => 'Dune' }, body_type: :form).status).to eq(201)
  end

  it 'sends a multipart request when body_type is :multipart' do
    path = File.join(Dir.mktmpdir, 'cover.jpg')
    File.write(path, 'jpeg-data')
    stub_request(:post, 'https://api.bookstore.example/upload')
      .to_return(status: 200, body: '{}')
    client = described_class.new(make_config)
    response = client.call(method: :post, path: '/upload', body: { 'cover' => "@#{path}" }, body_type: :multipart)
    expect(response.status).to eq(200)
    signature = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first
    expect(signature.headers['Content-Type']).to match(%r{\Amultipart/form-data})
  end
end
