require 'thor'

module RubyOpenapiCli
  class Cli < Thor
    def self.start(argv)
      RubyOpenapiCli.registry.start(argv)
    end
  end
end
