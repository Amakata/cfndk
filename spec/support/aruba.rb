require 'aruba/rspec'

Aruba.configure do |config|
  config.exit_timeout = 60 * 5
  config.working_directory = "tmp/aruba#{ENV['TEST_ENV_NUMBER']}"
end
