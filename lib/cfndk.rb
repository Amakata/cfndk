require 'bundler/setup'

require 'rainbow/ext/string'
require 'camelizable'
require 'fileutils'
require 'pathname'
require 'ostruct'
require 'erb'
require 'yaml'
require 'json'
require 'zip'
require 'aws-sdk-ec2'
require 'aws-sdk-s3'
require 'aws-sdk-cloudformation'
require 'terminal-table'
require 'securerandom'
require 'logger'
require 'thor'
require 'diff/lcs'
require 'diff/lcs/hunk'
require 'polyfill'

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
require 'cfndk/global_config'
require 'cfndk/logger'
require 'cfndk/credential_provider_chain'
require 'cfndk/subcommand_help_returnable'
require 'cfndk/credential_resolvable'
require 'cfndk/config_file_loadable'
require 'cfndk/key_pair_command'
require 'cfndk/stack_command'
require 'cfndk/change_set_command'
require 'cfndk/command'
require 'cfndk/template_packager'
require 'cfndk/diff'
require 'cfndk/uuid'

module CFnDK
end
