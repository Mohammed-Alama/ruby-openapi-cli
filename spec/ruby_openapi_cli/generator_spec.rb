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
