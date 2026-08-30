# ruby-openapi-cli — Design

**Date:** 2026-08-30
**Status:** Approved (via brainstorming)

A Ruby / Ruby-on-Rails equivalent of the Spatie Laravel OpenAPI CLI. Reads an
OpenAPI 3 spec (local or remote) and dynamically registers CLI commands that let
a developer fire requests against the API from the terminal — in a standalone
script or directly inside `bin/rails`.

## Goal

Let a developer run `bookstore:get-books --limit 2` (or the standalone
equivalent) from the terminal. The command is derived at runtime from an OpenAPI
spec: path templates become commands, path parameters become positional
arguments, query parameters become flags. The command performs the HTTP request
and prints a formatted response.

## Non-Goals

- No static code generation. Commands are built in memory at runtime (the
  Spatie way), not written out as tracked Ruby files.
- No SDK / client code generation for library consumers.
- No interactive request builder or REPL.

## Core Components

The gem is split into five small, independently-testable modules.

### 1. `RubyOpenapiCli::Configuration`

Holds user-defined settings per registered API: spec URL/path, `base_url`,
auth token/credential, `cache_ttl`, and default output `format`. Each registered
API gets its own configuration instance.

### 2. `RubyOpenapiCli::SpecParser`

Fetches the OpenAPI YAML/JSON spec (local file or over HTTP) and parses it into
a Ruby object using an existing parser gem (`openapi3_parser` /
`openapi_parser`). Extracts: paths, HTTP verbs, parameters (path/query/header),
request bodies, and response media types. Caches the downloaded/parsed spec to a
local path honoring `cache_ttl` so repeated boots don't re-fetch and re-parse
the network file.

### 3. `RubyOpenapiCli::CommandBuilder`

The Thor engine. Takes the parsed spec and dynamically injects commands into a
base Thor class:

- `GET /books/{id}` → command `get-books`, with `{id}` a required positional
  argument and query parameters exposed as Thor options (`--limit 2`).
- Handles all HTTP verbs (get, post, put, patch, delete).
- Request bodies are passed as an argument or option.

### 4. `RubyOpenapiCli::Client`

The Faraday wrapper / execution engine. A dynamic command calls through to this
with endpoint, method, and resolved parameters. Configures Faraday with base
URL, authentication headers, and payload, fires the request, and returns the
response. Supports middleware for auth and retries.

### 5. `RubyOpenapiCli::Formatter`

Turns a Faraday response into terminal output. Supports JSON, YAML, and Table
formats, honoring the user's `--format` flag or the configured default.

## Integration

### Standalone usage

The user writes a small executable that configures the gem and starts the
generated Thor CLI:

```ruby
#!/usr/bin/env ruby
require 'ruby_openapi_cli'

registry = RubyOpenapiCli.register('https://api.bookstore.io/openapi.yaml', 'bookstore') do |config|
  config.base_url = 'https://api.bookstore.io'
  config.auth_token = ENV['BOOKSTORE_TOKEN']
  config.cache_ttl = 600
  config.default_format = :table # or :json, :yaml
end

registry.start(ARGV)
```

### Ruby on Rails integration

A Railtie hooks into the Rails boot process. Users configure in an initializer:

```ruby
# config/initializers/openapi_cli.rb
RubyOpenapiCli.setup do |config|
  config.register 'https://api.bookstore.io/openapi.yaml', 'bookstore' do |api|
    api.base_url = 'https://api.bookstore.io'
    api.auth_token = ENV['BOOKSTORE_TOKEN']
  end
end
```

The Railtie dynamically injects the commands into `Rails::Command`, so the user
runs `bin/rails bookstore:get-books --limit 2`.

## Bundling the Standalone CLI

The gem ships a generator to scaffold a distributable standalone CLI:

```
ruby-openapi-cli new my-api-cli
```

This scaffolds a complete, lightweight CLI project containing:

- `bin/my-api-cli` executable with configuration ready to go.
- A `.gemspec` automatically configured for the CLI.

The user can then `gem build my-api-cli.gemspec` to produce a `.gem` for
distribution and `gem install my-api-cli.gem` to install it globally.

## Command Execution Flow

When `bin/rails bookstore:get-books --limit 2` runs:

1. **Routing** — Thor receives `get-books`; the dynamic Thor class maps it to
   the `GET /books` endpoint in the spec.
2. **Parameter mapping** — Thor parses `--limit 2` and maps it to the OpenAPI
   query parameters. Path parameters (e.g., `{id}` in `/books/{id}`) map to
   required positional arguments.
3. **HTTP request** — `Client` configures Faraday with base URL, auth headers,
   and payload, then fires the request.
4. **Output formatting** — `Formatter` receives the response and prints it per
   the `--format` flag or configured default (Table, JSON, or YAML).
5. **Error handling** — Non-success statuses (e.g., 429 rate limited, 404 not
   found) are caught and printed as friendly, colored errors rather than raw
   stack traces.

## Dependencies

- `thor` — CLI / command framework (Rails already uses it).
- `faraday` — HTTP client with middleware support.
- `openapi3_parser` (or `openapi_parser`) — OpenAPI spec parsing.

## Testing

- Unit tests per module (Configuration, SpecParser, CommandBuilder, Client,
  Formatter).
- Integration test: build a Thor class from a small fixture spec and assert
  command/argument/flag mapping.
- Test the standalone scaffold generator output and the Railtie hooks.

## Success Criteria

- A developer can register an OpenAPI spec and immediately run requests from
  the terminal with no static code generation.
- CLI boots quickly (spec cached per `cache_ttl`).
- Works identically as a standalone script and inside Rails via `Rails::Command`.
- `ruby-openapi-cli new <name>` produces a buildable, installable gem.
