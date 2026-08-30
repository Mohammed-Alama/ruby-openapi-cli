# ruby-openapi-cli

Generate an API CLI from an OpenAPI 3 spec. Commands are derived at runtime —
no static code generation.

## Standalone

```ruby
# bin/my-cli
require 'ruby_openapi_cli'
registry = RubyOpenapiCli.register('https://api.example.com/openapi.yaml', 'api') do |config|
  config.base_url = 'https://api.example.com'
  config.auth_token = ENV['API_TOKEN']
  config.default_format = :table
end
registry.start(ARGV)
```

Run: `ruby bin/my-cli get_books --limit 2`

### Sending a request body

Commands that accept a body take `--field` (repeatable) to build a field map, or
`--input` to send raw JSON. `--field` and `--input` are mutually exclusive.

```bash
# Form fields (JSON unless the spec declares URL-encoded)
ruby bin/my-cli create_book --field title=Dune --field year=1965

# Raw JSON body
ruby bin/my-cli create_book --input '{"title":"Dune"}'

# File upload (a --field value starting with @ is sent as multipart/form-data)
ruby bin/my-cli upload_cover --field book_id=1 --field cover=@/path/cover.jpg
```

## Generator

```bash
ruby-openapi-cli new my-api-cli --spec https://api.example.com/openapi.yaml
cd my-api-cli && gem build my-api-cli.gemspec && gem install my-api-cli.gem
```

## Rails

```ruby
# config/initializers/openapi_cli.rb
RubyOpenapiCli.setup do |config|
  config.register 'https://api.example.com/openapi.yaml', 'bookstore' do |api|
    api.base_url = 'https://api.example.com'
    api.auth_token = ENV['API_TOKEN']
  end
end
```

Run: `bin/rails bookstore:get_books --limit 2`
