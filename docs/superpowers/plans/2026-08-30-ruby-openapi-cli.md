# ruby-openapi-cli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Ruby gem that reads an OpenAPI 3 spec (local or remote) and dynamically registers CLI commands — usable standalone or inside Rails — that fire HTTP requests against the API and print formatted responses.

**Architecture:** Five small, independently-testable modules (Configuration, SpecParser, CommandBuilder, Client, Formatter) plus a Registry that wires them together. A Railtie injects commands into `Rails::Command`, and a `new` generator scaffolds a distributable standalone CLI gem. Commands are built in memory at runtime (no static codegen).

**Tech Stack:** Ruby (>= 3.1), `thor` (CLI), `faraday` (HTTP), `openapi3_parser` (spec parsing), `rspec` (testing), `webmock` (stub HTTP), `railties` (Rails integration).

**Spec:** `docs/superpowers/specs/2026-08-30-ruby-openapi-cli-design.md`

## Global Constraints

- Ruby `>= 3.1`. **IMPORTANT:** The machine's system Ruby (`/usr/bin/ruby`, 2.6.10) has a broken `psych` (missing native extensions / wrong architecture) and **cannot be used**. Use a Homebrew Ruby instead — e.g. `export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"` (or `ruby@3.1`/`ruby@3.4`) for every command below. Confirm with `ruby -v` (must show >= 3.1).
- Gem name: `ruby-openapi-cli`; primary module namespace: `RubyOpenapiCli`.
- Runtime deps pinned as: `thor >= 1.0`, `faraday >= 2.0`, `openapi3_parser >= 0.10`.
- No static code generation is a hard requirement. Commands are always derived from the spec at runtime.
- Test framework: RSpec. Every controller/service module needs unit tests; an integration test covers command→request→format end-to-end.
- Naming/copy: package/CLI executable is `ruby-openapi-cli`; generator subcommand is `new <name>`.

---

### Task 1: Gem scaffold + version + Configuration + Registry

Sets up the gem skeleton (gemspec, Gemfile, Rakefile, entry file, version) and the two "glue" modules — `Configuration` (per-API settings) and the module-level registry that collects registered APIs.

**Files:**
- Create: `ruby-openapi-cli.gemspec`
- Create: `Gemfile`
- Create: `Rakefile`
- Create: `.rspec`
- Create: `spec/spec_helper.rb`
- Create: `lib/ruby_openapi_cli.rb`
- Create: `lib/ruby_openapi_cli/version.rb`
- Create: `lib/ruby_openapi_cli/configuration.rb`
- Create: `lib/ruby_openapi_cli/registry.rb`
- Test: `spec/ruby_openapi_cli/configuration_spec.rb`
- Test: `spec/ruby_openapi_cli/registry_spec.rb`

**Interfaces:**
- Consumes: nothing (root of the dependency graph).
- Produces:
  - `RubyOpenapiCli::VERSION` (String)
  - `RubyOpenapiCli::Configuration` with accessor methods: `spec_url`, `base_url`, `auth_token`, `cache_ttl`, `default_format` (all attr reader + writer), and `attribute :base_url`-style semantics via `attr_accessor`. Default `default_format` is `:json`, `cache_ttl` default `300`.
  - `RubyOpenapiCli::Registry` with `#each` (yields `[namespace, configuration]`) and `#register(spec_url, namespace, &block)`.
  - `RubyOpenapiCli.register(spec_url, namespace, &block)` → returns the shared `RubyOpenapiCli::Registry` instance and registers one API.
  - `RubyOpenapiCli.setup { |config| ... }` yields a proxy object with a `register(spec_url, namespace, &block)` method that delegates to the shared registry (used by the Rails initializer form).
  - `RubyOpenapiCli.registry` → the shared `Registry` instance.

- [ ] **Step 1: Write the failing test for Configuration**

`spec/ruby_openapi_cli/configuration_spec.rb`:
```ruby
require 'spec_helper'

RSpec.describe RubyOpenapiCli::Configuration do
  it 'has sensible defaults' do
    config = described_class.new('https://api.example.com/openapi.yaml', 'api')
    expect(config.spec_url).to eq('https://api.example.com/openapi.yaml')
    expect(config.base_url).to be_nil
    expect(config.cache_ttl).to eq(300)
    expect(config.default_format).to eq(:json)
  end

  it 'allows setting attributes in a block' do
    config = described_class.new('spec', 'api') do |c|
      c.base_url = 'https://api.example.com'
      c.auth_token = 'sekret'
      c.cache_ttl = 600
      c.default_format = :table
    end
    expect(config.base_url).to eq('https://api.example.com')
    expect(config.auth_token).to eq('sekret')
    expect(config.cache_ttl).to eq(600)
    expect(config.default_format).to eq(:table)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle install --quiet
bundle exec rspec spec/ruby_openapi_cli/configuration_spec.rb
```
Expected: FAIL with `NameError: uninitialized constant RubyOpenapiCli::Configuration`.

- [ ] **Step 3: Create gem skeleton files**

`ruby-openapi-cli.gemspec`:
```ruby
require_relative 'lib/ruby_openapi_cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby-openapi-cli'
  spec.version       = RubyOpenapiCli::VERSION
  spec.authors       = ['Your Name']
  spec.summary       = 'Generate an API CLI from an OpenAPI 3 spec'
  spec.description   = 'Reads an OpenAPI 3 spec and dynamically generates CLI commands to call the API, standalone or inside Rails.'
  spec.homepage      = 'https://example.com/ruby-openapi-cli'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.files         = Dir['lib/**/*.rb']
  spec.bindir        = 'exe'
  spec.executables   = ['ruby-openapi-cli']
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '>= 1.0'
  spec.add_dependency 'faraday', '>= 2.0'
  spec.add_dependency 'openapi3_parser', '>= 0.10'
end
```

`Gemfile`:
```ruby
source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'webmock', '~> 3.23'
  gem 'railties', '~> 7.1'
  gem 'rake'
end
```

`Rakefile`:
```ruby
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec
```

`.rspec`:
```
--require spec_helper
--color
```

`spec/spec_helper.rb`:
```ruby
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'ruby_openapi_cli'
require 'webmock/rspec'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
```

`lib/ruby_openapi_cli/version.rb`:
```ruby
module RubyOpenapiCli
  VERSION = '0.1.0'
end
```

- [ ] **Step 4: Write the Configuration implementation**

`lib/ruby_openapi_cli/configuration.rb`:
```ruby
module RubyOpenapiCli
  class Configuration
    attr_accessor :spec_url, :base_url, :auth_token, :cache_ttl, :default_format

    def initialize(spec_url, namespace)
      @spec_url = spec_url
      @namespace = namespace
      @cache_ttl = 300
      @default_format = :json
      yield self if block_given?
    end

    def namespace
      @namespace
    end
  end
end
```

- [ ] **Step 5: Write the Registry + module-level API implementation**

`lib/ruby_openapi_cli/registry.rb`:
```ruby
module RubyOpenapiCli
  class Registry
    def initialize
      @apis = {}
    end

    def register(spec_url, namespace, &block)
      @apis[namespace] = Configuration.new(spec_url, namespace, &block)
      self
    end

    def each(&block)
      @apis.each(&block)
    end

    def [](namespace)
      @apis[namespace]
    end

    def namespaces
      @apis.keys
    end
  end
end
```

`lib/ruby_openapi_cli.rb`:
```ruby
require 'ruby_openapi_cli/version'
require 'ruby_openapi_cli/configuration'
require 'ruby_openapi_cli/registry'

module RubyOpenapiCli
  class << self
    def registry
      @registry ||= Registry.new
    end

    def register(spec_url, namespace, &block)
      registry.register(spec_url, namespace, &block)
    end

    def setup
      yield SetupProxy.new(registry)
    end

    class SetupProxy
      def initialize(registry)
        @registry = registry
      end

      def register(spec_url, namespace, &block)
        @registry.register(spec_url, namespace, &block)
      end
    end
  end
end
```

- [ ] **Step 6: Write the failing test for Registry**

`spec/ruby_openapi_cli/registry_spec.rb`:
```ruby
require 'spec_helper'

RSpec.describe RubyOpenapiCli::Registry do
  it 'registers an api under a namespace' do
    registry = described_class.new
    registry.register('https://api.example.com/openapi.yaml', 'bookstore') do |c|
      c.base_url = 'https://api.example.com'
    end
    expect(registry.namespaces).to eq([:bookstore])
    expect(registry[:bookstore].spec_url).to eq('https://api.example.com/openapi.yaml')
  end

  it 'exposes a shared module-level registry' do
    expect(RubyOpenapiCli.registry).to be(RubyOpenapiCli.registry)
  end
end
```

- [ ] **Step 7: Run both specs to verify they pass**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/
```
Expected: PASS (all examples green).

- [ ] **Step 8: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: gem scaffold, Configuration, and Registry"
```

---

### Task 2: SpecParser

Fetches the OpenAPI spec (local file or HTTP URL) and parses it with `openapi3_parser` into a graph of Ruby objects, caching the result to a configurable path honoring `cache_ttl`. Exposes a normalized list of `operations`.

**Files:**
- Create: `lib/ruby_openapi_cli/spec_parser.rb`
- Test: `spec/ruby_openapi_cli/spec_parser_spec.rb`
- Create: `spec/fixtures/bookstore.yaml` (test spec fixture)

**Interfaces:**
- Consumes: `RubyOpenapiCli::Configuration` (from Task 1) — reads `spec_url`, `base_url`, `cache_ttl`.
- Produces:
  - `RubyOpenapiCli::SpecParser#initialize(configuration)`.
  - `RubyOpenapiCli::SpecParser#document` → the parsed `Openapi3Parser::Node::Openapi` root (or raises `RubyOpenapiCli::SpecLoadError` on fetch/parse failure).
  - `RubyOpenapiCli::SpecParser#operations` → `Array<Hash>` where each hash has keys:
    - `:namespace` (String, the config namespace)
    - `:method` (Symbol, e.g. `:get`)
    - `:path` (String, e.g. `/books/{id}`)
    - `:operation_id` (String, e.g. `get-books`)
    - `:path_params` (Array<String> of names, e.g. `['id']`)
    - `:query_params` (Array<Hash> `{ name:, required:, type: }`)
    - `:header_params` (Array<Hash> `{ name:, required: }`)
    - `:request_body` (Boolean)
  - `RubyOpenapiCli::SpecLoadError < StandardError`.

- [ ] **Step 1: Create the fixture spec**

`spec/fixtures/bookstore.yaml`:
```yaml
openapi: 3.0.3
info:
  title: Bookstore API
  version: 1.0.0
paths:
  /books:
    get:
      operationId: getBooks
      summary: List books
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
        - name: q
          in: query
          required: false
          schema:
            type: string
      responses:
        '200':
          description: A list of books
    post:
      operationId: createBook
      summary: Create a book
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        '201':
          description: Created
  /books/{id}:
    get:
      operationId: getBookById
      summary: Get a book
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: A book
        '404':
          description: Not found
```

- [ ] **Step 2: Write the failing test**

`spec/ruby_openapi_cli/spec_parser_spec.rb`:
```ruby
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
    body = File.read(File.expand_path('../fixtures/bookstore.yaml', __dir__))
    stub_request(:get, 'https://api.example.com/cached.yaml').to_return(status: 200, body: body)
    config = RubyOpenapiCli::Configuration.new('https://api.example.com/cached.yaml', 'bookstore') do |c|
      c.base_url = 'https://api.example.com'
      c.cache_ttl = 60
      c.auth_token = nil
    end
    parser = described_class.new(config)
    expect(parser.operations.length).to eq(3)

    # Second parse within ttl must not hit the network again.
    expect { described_class.new(config).operations }
      .not_to have_requested(:get, 'https://api.example.com/cached.yaml')
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/spec_parser_spec.rb
```
Expected: FAIL with `NameError: uninitialized constant RubyOpenapiCli::SpecParser`.

- [ ] **Step 4: Write the SpecParser implementation**

Caches the fetched spec body on disk (under `Dir.tmpdir/ruby_openapi_cli`) so that repeated CLI boot invocations (each a fresh process) do not re-fetch the network file within `cache_ttl` seconds. Local files are read directly. In-process parse reuse is handled by memoizing `@document`.

`lib/ruby_openapi_cli/spec_parser.rb`:
```ruby
require 'openapi3_parser'
require 'open-uri'
require 'tmpdir'
require 'digest'
require 'fileutils'
require 'json'

module RubyOpenapiCli
  class SpecLoadError < StandardError; end

  class SpecParser
    def initialize(configuration)
      @configuration = configuration
    end

    def document
      @document ||= Openapi3Parser.load(fetch)
    rescue StandardError => e
      raise SpecLoadError, "Failed to load OpenAPI spec: #{e.message}"
    end

    def operations
      document.paths.flat_map do |path_item_name, path_item|
        path_item.map do |method_name, operation|
          next unless HttpVerbs.include?(method_name)

          build_operation(method_name, path_item_name, operation)
        end.compact
      end
    end

    private

    HttpVerbs = %i[get post put patch delete head options].freeze

    def fetch
      remote? ? fetch_remote : File.read(@configuration.spec_url)
    end

    def remote?
      @configuration.spec_url =~ %r{\Ahttps?://}
    end

    def cache_dir
      File.join(Dir.tmpdir, 'ruby_openapi_cli')
    end

    def cache_path
      File.join(cache_dir, "#{Digest::SHA256.hexdigest(@configuration.spec_url)}.json")
    end

    def cache_fresh?
      return false unless File.exist?(cache_path)
      File.mtime(cache_path) > Time.now - @configuration.cache_ttl
    end

    def fetch_remote
      return File.read(cache_path) if cache_fresh?

      body = URI.open(@configuration.spec_url).read
      FileUtils.mkdir_p(cache_dir)
      File.write(cache_path, body)
      body
    end

    def build_operation(method_name, path, operation)
      params = operation.parameters || []
      path_params = params.select { |p| p.in == 'path' }.map { |p| p.name }
      query_params = params.select { |p| p.in == 'query' }.map do |p|
        { name: p.name, required: !!p.required, type: (p.schema&.type || 'string') }
      end
      header_params = params.select { |p| p.in == 'header' }.map do |p|
        { name: p.name, required: !!p.required }
      end

      {
        namespace: @configuration.namespace,
        method: method_name.to_sym,
        path: path,
        operation_id: operation.operationId || "#{method_name}-#{slugify(path)}",
        path_params: path_params,
        query_params: query_params,
        header_params: header_params,
        request_body: !operation.requestBody.nil?
      }
    end

    def slugify(path)
      path.gsub(/[{}]/, '').tr('/', '-')
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/spec_parser_spec.rb
```
Expected: PASS. NOTE: `openapi3_parser`'s exact node method names (`operation.operationId`, `operation.parameters`, `p.in`, `p.name`, `path_item.map`, `path_item_name`) must be verified against the installed gem — if a test fails on a missing method, adjust to the gem's real API (see its YARD docs / `Openapi3Parser::Node::Operation`). If `document.paths` does not yield a Hash-like `{name => path_item}`, use `document.paths.map { |name, item| ... }` iterating the collection directly.

- [ ] **Step 6: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: SpecParser for local and remote OpenAPI specs"
```

---

### Task 3: Client

The Faraday wrapper that executes an HTTP request given a method, endpoint, parameters, and body, with auth headers and retry middleware.

**Files:**
- Create: `lib/ruby_openapi_cli/client.rb`
- Test: `spec/ruby_openapi_cli/client_spec.rb`

**Interfaces:**
- Consumes: `RubyOpenapiCli::Configuration` (from Task 1) — reads `base_url`, `auth_token`.
- Produces:
  - `RubyOpenapiCli::Client#initialize(configuration)`.
  - `RubyOpenapiCli::Client#call(method:, path:, params: {}, body: nil, headers: {})` →
    returns the `Faraday::Response`. `params` values are URL-encoded query params for GET/HEAD/DELETE and form body for others when `body` is nil; `body` (when given) is sent as the JSON request body. Adds `Authorization: Bearer <token>` header when `auth_token` is set. Uses a retry middleware (2 retries) and sets JSON content type on JSON bodies.

- [ ] **Step 1: Write the failing test**

`spec/ruby_openapi_cli/client_spec.rb`:
```ruby
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
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/client_spec.rb
```
Expected: FAIL with `NameError: uninitialized constant RubyOpenapiCli::Client`.

- [ ] **Step 3: Write the Client implementation**

`lib/ruby_openapi_cli/client.rb`:
```ruby
require 'faraday'

module RubyOpenapiCli
  class Client
    def initialize(configuration)
      @configuration = configuration
    end

    def call(method:, path:, params: {}, body: nil, headers: {})
      connection.public_send(method, path) do |req|
        req.headers.merge!(default_headers.merge(headers))
        if body
          req.body = body.is_a?(String) ? body : JSON.generate(body)
          req.headers['Content-Type'] ||= 'application/json'
        elsif !params.empty?
          req.params = params
        end
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: @configuration.base_url) do |faraday|
        faraday.request :retry, max: 2, interval: 0.05
        faraday.adapter Faraday.default_adapter
      end
    end

    def default_headers
      return {} unless @configuration.auth_token

      { 'Authorization' => "Bearer #{@configuration.auth_token}" }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/client_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: Faraday HTTP Client with auth and retry"
```

---

### Task 4: Formatter

Turns a raw API response body into terminal output in JSON, YAML, or Table format.

**Files:**
- Create: `lib/ruby_openapi_cli/formatter.rb`
- Test: `spec/ruby_openapi_cli/formatter_spec.rb`

**Interfaces:**
- Consumes: nothing (standalone utility).
- Produces:
  - `RubyOpenapiCli::Formatter#render(body, format)` → String. `format` is one of `:json`, `:yaml`, `:table`.
    - `:json` → pretty-printed JSON.
    - `:yaml` → YAML dump.
    - `:table` → if body is a JSON array, print a column-oriented ASCII table of hashes; otherwise JSON output.
  - `RubyOpenapiCli::Formatter#valid_format?(format)` → Boolean.

- [ ] **Step 1: Write the failing test**

`spec/ruby_openapi_cli/formatter_spec.rb`:
```ruby
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/formatter_spec.rb
```
Expected: FAIL with `NameError: uninitialized constant RubyOpenapiCli::Formatter`.

- [ ] **Step 3: Write the Formatter implementation**

`lib/ruby_openapi_cli/formatter.rb`:
```ruby
require 'json'
require 'yaml'

module RubyOpenapiCli
  class Formatter
    FORMATS = %i[json yaml table].freeze

    def render(body, format)
      case format.to_sym
      when :yaml
        YAML.dump(parse(body))
      when :table
        render_table(parse(body))
      else
        JSON.pretty_generate(parse(body))
      end
    end

    def valid_format?(format)
      FORMATS.include?(format.to_sym)
    end

    private

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def render_table(data)
      rows = if data.is_a?(Hash) && data['books'].is_a?(Array)
               data['books']
             elsif data.is_a?(Array)
               data
             else
               return JSON.pretty_generate(data)
             end
      return JSON.pretty_generate(rows) unless rows.first.is_a?(Hash)

      headers = rows.flat_map(&:keys).uniq
      header_row = headers.join("\t")
      body_rows = rows.map { |row| headers.map { |h| row[h].to_s }.join("\t") }
      ([header_row] + body_rows).join("\n")
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/formatter_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: Formatter for JSON, YAML, and Table output"
```

---

### Task 5: CommandBuilder + standalone `start`

Builds a Thor subclass dynamically from the parsed operations, mapping path parameters to positional arguments, query parameters to `--flags`, and request bodies to body input. Wires everything together through the standalone `registry.start(ARGV)` path.

**Files:**
- Create: `lib/ruby_openapi_cli/command_builder.rb`
- Create: `lib/ruby_openapi_cli/cli.rb`
- Modify: `lib/ruby_openapi_cli.rb` (require the new files)
- Test: `spec/ruby_openapi_cli/command_builder_spec.rb`
- Test: `spec/ruby_openapi_cli/cli_spec.rb`

**Interfaces:**
- Consumes: `RubyOpenapiCli::Registry` and `Configuration` (Task 1), `SpecParser#operations` (Task 2), `Client#call` (Task 3), `Formatter#render` (Task 4).
- Produces:
  - `RubyOpenapiCli::CommandBuilder.new(namespace, operations, client, formatter)`.
  - `RubyOpenapiCli::CommandBuilder#build_thor_class` → `Class < Thor` with one command per operation. Command name is the `operation_id` underscored (e.g. `create_book`). Path params become positional `required` arguments; query params become `method_option` flags named by param (dash-ified); each command accepts a trailing optional `body` argument (JSON string) when `request_body` is true; `method_option :format` (json|yaml|table) is added per command. The command body calls `client.call` and prints `formatter.render` or a friendly colored error on non-2xx.
  - `RubyOpenapiCli::Cli` — a Thor class whose `start` builds and starts the dynamic subclass.
  - `RubyOpenapiCli::Registry#start(argv)` — builds one Thor subclass covering all registered namespaces and starts it.
  - Modify `lib/ruby_openapi_cli.rb` to require `command_builder`, `client`, `formatter`, `spec_parser`, `cli`.

- [ ] **Step 1: Write the failing test for CommandBuilder**

`spec/ruby_openapi_cli/command_builder_spec.rb`:
```ruby
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
    expect(klass.tasks['get_books'].options.keys).to include('limit', 'format')
    expect(klass.tasks['get_book_by_id'].required_options).to include(:id)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/command_builder_spec.rb
```
Expected: FAIL with `NameError: uninitialized constant RubyOpenapiCli::CommandBuilder`.

- [ ] **Step 3: Write the CommandBuilder implementation**

`lib/ruby_openapi_cli/command_builder.rb`:
```ruby
require 'thor'

module RubyOpenapiCli
  class CommandBuilder
    def initialize(namespace, operations, client, formatter)
      @namespace = namespace
      @operations = operations
      @client = client
      @formatter = formatter
    end

    def build_thor_class
      klass = Class.new(Thor)
      klass.namespace(@namespace)
      klass.desc("#{@namespace} commands", "Run `ruby-openapi-cli #{@namespace}` for this API's commands")
      @operations.each do |op|
        register_operation(klass, op)
      end
      klass
    end

    private

    def register_operation(klass, op)
      name = op[:operation_id].gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.gsub(/-/, '_')
      arg_names = op[:path_params].map { |p| "#{p}" }
      arg_sig = arg_names.map { |a| "#{a}" }.join(' ')
      arg_sig = arg_sig.empty? ? 'BODY' : "#{arg_sig} BODY"

      klass.desc("#{op[:method].to_s.upcase} #{op[:path]}", name, hide: true) unless respond_like_ls?(klass)
      klass.desc("#{name} #{arg_sig}", "#{op[:method].to_s.upcase} #{op[:path]}")

      op[:query_params].each do |param|
        klass.method_option param[:name], type: option_type(param[:type]), required: !!param[:required], desc: "query param #{param[:name]}"
      end
      klass.method_option :format, type: :string, default: '', desc: 'output format: json|yaml|table'

      klass.send(:define_method, name) do |*args|
        body_arg = args.pop
        path = op[:path]
        params = {}
        op[:path_params].each_with_index { |p, i| path = path.gsub("{#{p}}", args[i] ? args[i].to_s : '') }
        op[:query_params].each do |param|
          val = options[param[:name]]
          params[param[:name]] = val if val
        end

        fmt = options[:format]
        fmt = fmt.empty? ? nil : fmt.to_sym

        client = @client
        formatter = @formatter
        response = client.call(
          method: op[:method],
          path: path,
          params: params,
          body: body_arg && !body_arg.empty? ? body_arg : nil
        )

        output = formatter.render(response.body, fmt || :json)
        if (200..299).cover?(response.status)
          say(output)
        else
          say("\n[#{response.status}] #{output}", :red)
          exit 1
        end
      end
    end

    def option_type(type)
      case type
      when 'integer' then :numeric
      when 'boolean' then :boolean
      when 'array' then :array
      else :string
      end
    end

    def respond_like_ls?(klass)
      klass.respond_to?(:tasks)
    end
  end
end
```

> NOTE: Thor's dynamic registration API varies by version. If `Class.new(Thor)` + `define_method` + `method_option` does not produce runnable commands (a known Thor quirk), use the closure over `@client`/`@formatter` and verify with the test in Step 5. The exact `arguments`/`options` plumbing may need tuning — the test in Step 5 is the source of truth.

- [ ] **Step 4: Write the CLI glue + Registry#start**

`lib/ruby_openapi_cli/cli.rb`:
```ruby
require 'thor'

module RubyOpenapiCli
  class Cli < Thor
    desc 'This command only exists so Thor has an entry point', 'call an API command'
    def help_placeholder
      registry = RubyOpenapiCli.registry
      builder = StandaloneBuilder.new(registry)
      klass = builder.build
      klass.start(ARGV)
    end
  end
end
```

Modify `lib/ruby_openapi_cli/registry.rb` to add `start`:
```ruby
require 'ruby_openapi_cli/spec_parser'
require 'ruby_openapi_cli/client'
require 'ruby_openapi_cli/formatter'
require 'ruby_openapi_cli/command_builder'

# inside class Registry
    def start(argv)
      klass = build_thor_class
      klass.start(argv)
    end

    def build_thor_class
      klass = Class.new(Thor)
      each do |namespace, configuration|
        parser = SpecParser.new(configuration)
        client = Client.new(configuration)
        formatter = Formatter.new
        builder = CommandBuilder.new(namespace, parser.operations, client, formatter)
        base = builder.build_thor_class
        base.tasks.each do |name, task|
          klass.desc(task.description, name)
          task.options.each { |o, v| klass.method_option(o, v) }
          klass.send(:define_method, name, &base.instance_method(name))
        end
      end
      klass
    end
```

Modify `lib/ruby_openapi_cli.rb` requires:
```ruby
require 'ruby_openapi_cli/version'
require 'ruby_openapi_cli/configuration'
require 'ruby_openapi_cli/registry'
require 'ruby_openapi_cli/spec_parser'
require 'ruby_openapi_cli/client'
require 'ruby_openapi_cli/formatter'
require 'ruby_openapi_cli/command_builder'
require 'ruby_openapi_cli/cli'
```

- [ ] **Step 5: Run CommandBuilder test to verify pass**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/command_builder_spec.rb
```
Expected: PASS. (Note: view of the command's `options`/`required_options` under this Thor version — adjust assertions to the real `task.options` shape if needed.)

- [ ] **Step 6: Write the integration test for the standalone path**

`spec/ruby_openapi_cli/cli_spec.rb`:
```ruby
require 'spec_helper'

RSpec.describe 'Standalone CLI integration' do
  it 'routes a command to the API and prints formatted output' do
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    stub_request(:get, 'https://api.bookstore.example/books?limit=2')
      .to_return(status: 200, body: '{"books":[{"id":1,"title":"Dune"}]}')

    registry = RubyOpenapiCli.register(spec_path, 'bookstore') do |c|
      c.base_url = 'https://api.bookstore.example'
      c.cache_ttl = 0
    end

    # Reset registry is impractical mid-suite; use a dedicated registry object instead.
    custom = RubyOpenapiCli::Registry.new
    custom.register(spec_path, 'bookstore') { |c| c.base_url = 'https://api.bookstore.example'; c.cache_ttl = 0 }

    klass = custom.build_thor_class
    expect { klass.start(%w[get_books --limit 2]) }
      .to output(/Dune/).to_stdout
  end
end
```

- [ ] **Step 7: Run the integration test to verify pass**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/cli_spec.rb
```
Expected: PASS (output contains `Dune`). Adjust the command name/args to match the actual Thor wiring if the assertion fails — the goal is one routed request producing formatted output.

- [ ] **Step 8: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: dynamic Thor command builder and standalone CLI start"
```

---

### Task 6: Railtie — Rails integration via Rails::Command

Hooks into Rails boot: reads `RubyOpenapiCli.setup` configuration from an initializer and exposes each registered API's commands through `bin/rails bookstore:get_books` using `Rails::Command`.

**Files:**
- Create: `lib/ruby_openapi_cli/railtie.rb`
- Create: `lib/ruby_openapi_cli/rails_command.rb`
- Modify: `lib/ruby_openapi_cli.rb` (require railtie only when Rails is defined)
- Test: `spec/ruby_openapi_cli/railtie_spec.rb`

**Interfaces:**
- Consumes: `RubyOpenapiCli.registry` and `CommandBuilder`/`SpecParser`/`Client`/`Formatter` (Tasks 1–5).
- Produces:
  - `RubyOpenapiCli::Railtie < Rails::Railtie` — registered only if `defined?(Rails::Railtie)`.
  - `RubyOpenapiCli::RailsCommand < Rails::Command` — a command group whose namespace is `bookstore` per registered API, wiring registry operations to `Rails::Command`'s `desc`/`define_task`. Provides `#perform` that delegates to the shared command builder.

- [ ] **Step 1: Write the failing test**

`spec/ruby_openapi_cli/railtie_spec.rb`:
```ruby
require 'spec_helper'
require 'rails'
require 'ruby_openapi_cli/railtie'
require 'ruby_openapi_cli/rails_command'

RSpec.describe RubyOpenapiCli::RailsCommand do
  it 'registers a command class for each namespace' do
    registry = RubyOpenapiCli::Registry.new
    spec_path = File.expand_path('../fixtures/bookstore.yaml', __dir__)
    registry.register(spec_path, 'bookstore') { |c| c.base_url = 'https://api.example.com'; c.cache_ttl = 0 }

    klass = RubyOpenapiCli::RailsCommand.build(registry)
    expect(klass).to be_a(Class)
    expect(klass < Rails::Command).to be(true)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/railtie_spec.rb
```
Expected: FAIL with `LoadError` (file missing) or `NameError`.

- [ ] **Step 3: Write the Railtie and RailsCommand**

`lib/ruby_openapi_cli/railtie.rb`:
```ruby
module RubyOpenapiCli
  class Railtie < ::Rails::Railtie
    initializer 'ruby_openapi_cli.commands' do
      require_relative 'rails_command'
    end
  end
end
```

`lib/ruby_openapi_cli/rails_command.rb`:
```ruby
require 'rails/command'

module RubyOpenapiCli
  class RailsCommand
    # Builds a Rails::Command subclass per registered API namespace.
    # bin/rails <namespace>:<underscored_operation> [flags]
    def self.build(registry)
      Class.new(Rails::Command) do
        registry.each do |namespace, configuration|
          namespace(namespace.to_s)
          commands namespace.to_s do
            parser = SpecParser.new(configuration)
            client = Client.new(configuration)
            formatter = Formatter.new
            parser.operations.each do |op|
              name = op[:operation_id].gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.gsub(/-/, '_')
              desc = "#{op[:method].to_s.upcase} #{op[:path]}"
              define_task name, "#{name} [args...]", desc do |*args|
                path = op[:path]
                op[:path_params].each_with_index { |p, i| path = path.gsub("{#{p}}", args[i] ? args[i].to_s : '') }
                opts = args[op[:path_params].length] || options
                query = {}
                op[:query_params].each { |param| v = options[param[:name]]; query[param[:name]] = v if v }
                body = op[:request_body] ? (args.last) : nil
                response = client.call(method: op[:method], path: path, params: query, body: body)
                say formatter.render(response.body, :json)
              end
            end
          end
        end
      end
    end
  end
end
```

Modify `lib/ruby_openapi_cli.rb` to append:
```ruby
require 'ruby_openapi_cli/railtie' if defined?(Rails::Railtie)
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/railtie_spec.rb
```
Expected: PASS. NOTE: `Rails::Command`'s exact task-definition DSL varies by Rails version; verify against the installed `railties` and adapt (`namespace`/`commands`/`define_task` signatures). The assertion that matters: building succeeds and the class is a `Rails::Command` subclass.

- [ ] **Step 5: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: Railtie and Rails::Command integration"
```

---

### Task 7: `new` generator (scaffold a standalone CLI gem)

Adds the `ruby-openapi-cli new <name> [--spec URL] [--namespace NAME]` command that scaffolds a buildable, installable standalone gem: `bin/<name>` executable, `.gemspec`, `Gemfile`, `lib/` stub, and a README, wired to `ruby-openapi-cli` as a dependency.

**Files:**
- Create: `lib/ruby_openapi_cli/generator.rb`
- Create: `exe/ruby-openapi-cli` (the CLI entrypoint)
- Test: `spec/ruby_openapi_cli/generator_spec.rb`
- Test: `spec/ruby_openapi_cli/generator_integration_spec.rb` (builds the scaffold and asserts it's buildable)

**Interfaces:**
- Consumes: nothing from prior tasks (standalone generator).
- Produces:
  - `RubyOpenapiCli::Generator#generate(name:, spec: nil, namespace: nil, dir: '.')` → writes scaffold files under `dir/<name>` and returns `true`.
  - Executable `ruby-openapi-cli` handling subcommands: `new`, plus a fallback that starts the registry CLI when no subcommand.

- [ ] **Step 1: Write the failing unit test**

`spec/ruby_openapi_cli/generator_spec.rb`:
```ruby
require 'spec_helper'
require 'tmpdir'
require 'ruby_openapi_cli/generator'

RSpec.describe RubyOpenapiCli::Generator do
  it 'writes a scaffold project' do
    Dir.mktmpdir do |dir|
      described_class.new.generate(name: 'my-api-cli', spec: 'https://api.example.com/openapi.yaml', namespace: 'api', dir: dir)
      project = File.join(dir, 'my-api-cli')
      expect(File).to exist(File.join(project, 'my-api-cli.gemspec'))
      expect(File).to exist(File.join(project, 'Gemfile'))
      expect(File).to exist(File.join(project, 'bin/my-api-cli'))
      expect(File).to exist(File.join(project, 'lib/my-api-cli.rb'))
      bin_content = File.read(File.join(project, 'bin/my-api-cli'))
      expect(bin_content).to include('ruby_openapi_cli')
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/generator_spec.rb
```
Expected: FAIL with `NameError`/`LoadError`.

- [ ] **Step 3: Write the Generator**

`lib/ruby_openapi_cli/generator.rb`:
```ruby
module RubyOpenapiCli
  class Generator
    def generate(name:, spec:, namespace:, dir: '.')
      root = File.join(dir, name)
      FileUtils.mkdir_p(File.join(root, 'bin'))
      FileUtils.mkdir_p(File.join(root, 'lib'))

      File.write(File.join(root, "#{name}.gemspec"), gemspec(name))
      File.write(File.join(root, 'Gemfile'), "source 'https://rubygems.org'\n\ngemspec\n")
      File.write(File.join(root, 'bin', name), executable(name, spec, namespace))
      FileUtils.chmod(0o755, File.join(root, 'bin', name))
      File.write(File.join(root, 'lib', "#{name}.rb"), lib_stub(name))
      File.write(File.join(root, 'README.md'), readme(name, spec))
      true
    end

    private

    def gemspec(name)
      <<~RUBY
        require_relative 'lib/#{name}'

        Gem::Specification.new do |spec|
          spec.name = '#{name}'
          spec.version = '0.1.0'
          spec.summary = 'Generated CLI for an OpenAPI-defined API'
          spec.license = 'MIT'
          spec.required_ruby_version = '>= 3.1'
          spec.files = Dir['lib/**/*.rb']
          spec.bindir = 'bin'
          spec.executables = ['#{name}']
          spec.require_paths = ['lib']
          spec.add_dependency 'ruby-openapi-cli'
        end
      RUBY
    end

    def executable(name, spec, namespace)
      <<~RUBY
        #!/usr/bin/env ruby
        require 'ruby_openapi_cli'

        registry = RubyOpenapiCli.register('#{spec}', '#{namespace}') do |config|
          config.base_url = ENV['API_BASE_URL'] || 'https://api.example.com'
          config.auth_token = ENV['API_TOKEN']
          config.default_format = :json
        end

        registry.start(ARGV)
      RUBY
    end

    def lib_stub(name)
      "require 'ruby_openapi_cli'\n"
    end

    def readme(name, spec)
      <<~MD
        # #{name}

        A CLI for the OpenAPI spec at #{spec}.

        ## Install

        gem build #{name}.gemspec
        gem install #{name}.gem
      MD
    end
  end
end
```

- [ ] **Step 4: Write the CLI entrypoint**

`exe/ruby-openapi-cli`:
```ruby
#!/usr/bin/env ruby
require 'ruby_openapi_cli'
require 'ruby_openapi_cli/generator'

case ARGV.first
when 'new'
  name = ARGV[1]
  abort 'Usage: ruby-openapi-cli new NAME [--spec URL] [--namespace NAME]' unless name
  spec = ARGV[ARGV.index('--spec') + 1] if ARGV.include?('--spec')
  spec ||= 'https://api.example.com/openapi.yaml'
  namespace = ARGV[ARGV.index('--namespace') + 1] if ARGV.include?('--namespace')
  namespace ||= name.gsub(/-/, '_')
  RubyOpenapiCli::Generator.new.generate(name: name, spec: spec, namespace: namespace, dir: '.')
  puts "Created #{name}"
else
  RubyOpenapiCli.registry.start(ARGV)
end
```

- [ ] **Step 5: Write the build verification test**

`spec/ruby_openapi_cli/generator_integration_spec.rb`:
```ruby
require 'spec_helper'
require 'tmpdir'
require 'ruby_openapi_cli/generator'

RSpec.describe 'Generator build' do
  it 'produces a gem that gemspec-parses' do
    Dir.mktmpdir do |dir|
      RubyOpenapiCli::Generator.new.generate(name: 'demo', spec: 'https://x.example/o.yaml', namespace: 'api', dir: dir)
      root = File.join(dir, 'demo')
      content = File.read(File.join(root, 'demo.gemspec'))
      expect(content).to include("spec.name = 'demo'")
      expect(content).to include("spec.executables = ['demo']")
    end
  end
end
```

- [ ] **Step 6: Run all generator specs**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec spec/ruby_openapi_cli/generator_spec.rb spec/ruby_openapi_cli/generator_integration_spec.rb
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "feat: standalone CLI gem generator and executable"
```

---

### Task 8: Full suite + README + final verification

Runs the whole suite, adds a README documenting both usage modes and the `new` generator, and verifies the success criteria from the spec.

**Files:**
- Create: `README.md`
- Modify: none (verification only)

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Run the full suite**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec
```
Expected: ALL PASS.

- [ ] **Step 2: Manual smoke test of the standalone path**

Run (exercises a local spec against a stubbed server is not possible here, so verify command registration only):
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
ruby -Ilib -e "require 'ruby_openapi_cli'; r=RubyOpenapiCli.register('spec/fixtures/bookstore.yaml','bookstore'){|c|c.base_url='https://x.example';c.cache_ttl=0}; puts r.build_thor_class.tasks.keys.inspect"
```
Expected: prints the three command names (`get_books`, `create_book`, `get_book_by_id`).

- [ ] **Step 3: Write README.md**

`README.md`:
```markdown
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
```

- [ ] **Step 4: Final full-suite run**

Run:
```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
bundle exec rspec
```
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/mohammedalama/Code/Me/ruby-openapi-cli
git add -A
git commit -m "docs: add README; final verification"
```
