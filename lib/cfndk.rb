require 'bundler/setup'

require 'rainbow/ext/string'
require 'camelizable'
require 'fileutils'
require 'pathname'
require 'erb'
require 'yaml'
require 'json'
require 'aws-sdk'
require 'terminal-table'
require 'securerandom'
require 'logger'
require 'thor'

if ENV['CFNDK_COVERAGE']
  require 'simplecov'
  root = File.expand_path('../../', __FILE__)
  SimpleCov.root(root)
end

require 'cfndk/version'
require 'cfndk/stack'
require 'cfndk/stacks'
require 'cfndk/key_pair'
require 'cfndk/key_pairs'
require 'cfndk/erb_string'
require 'cfndk/logger'
require 'cfndk/credential_provider_chain'
require 'cfndk/command'

module CFnDK
end
