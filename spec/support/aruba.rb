require 'aruba/rspec'

Aruba.configure do |config|
  config.exit_timeout = 60 * 5
end
