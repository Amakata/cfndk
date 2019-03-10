require 'aruba/rspec'

Aruba.configure do |config|
  config.exit_timeout = 60 * 3
end
