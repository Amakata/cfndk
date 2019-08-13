# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cfndk/version'

Gem::Specification.new do |spec|
  spec.name          = 'cfndk'
  spec.version       = CFnDK::VERSION
  spec.authors       = ['Yoshihisa AMAKATA']
  spec.email         = ['amakata@gmail.com']
  spec.summary       = 'cfndk is AWS Cloud Formation Development Kit'
  spec.description   = 'cfndk is AWS Cloud Formation Development Kit'
  spec.homepage      = 'https://github.com/Amakata/cfndk'
  spec.license       = 'http://www.apache.org/licenses/license-2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'aruba'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'awspec'
  spec.add_development_dependency 'parallel_tests'

  spec.add_dependency 'bundler'
  spec.add_dependency 'thor'
  spec.add_dependency 'rainbow'
  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'camelizable'
  spec.add_dependency 'terminal-table'
end
