require 'fileutils'

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
