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
