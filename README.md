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
