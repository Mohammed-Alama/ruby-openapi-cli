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
