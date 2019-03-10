SimpleCov.merge_timeout 3600
SimpleCov.command_name "rspec_#{Process.pid.to_s}"

SimpleCov.start do
  add_filter 'spec'
  add_filter '.simplecov'

  add_group 'Libraries', 'lib'   
end
