$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'ruby_openapi_cli'
require 'webmock/rspec'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
