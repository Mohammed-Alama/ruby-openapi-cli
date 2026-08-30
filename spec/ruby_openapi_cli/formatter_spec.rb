require 'spec_helper'

RSpec.describe RubyOpenapiCli::Formatter do
  subject(:formatter) { described_class.new }

  it 'pretty-prints JSON' do
    out = formatter.render('{"a":1}', :json)
    expect { JSON.parse(out) }.not_to raise_error
    expect(out).to include('"a"')
  end

  it 'dumps YAML' do
    out = formatter.render('{"a":1}', :yaml)
    expect(out).to include('a: 1')
  end

  it 'renders an array of hashes as a table' do
    out = formatter.render('{"books":[{"id":1,"title":"Dune"}]}', :table)
    expect(out).to include('id')
    expect(out).to include('title')
    expect(out).to include('Dune')
  end

  it 'validates formats' do
    expect(formatter.valid_format?(:json)).to be(true)
    expect(formatter.valid_format?(:bogus)).to be(false)
  end
end
