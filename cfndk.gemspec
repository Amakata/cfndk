# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cfndk/version'

Gem::Specification.new do |spec|
  spec.name          = 'cfndk'
  spec.version       = CFnDK::VERSION
  spec.authors       = ['Yoshihisa AMAKATA']
  spec.email         = ['amakata@gmail.com']
  spec.summary       = 'cfn-dk is AWS Cloud Formation Development Kit'
  spec.description   = 'cfn-dk is AWS Cloud Formation Development Kit'
  spec.homepage      = 'https://github.com/Amakata/cfndk'
  spec.license       = 'http://www.apache.org/licenses/license-2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 11.1.2'

  spec.add_dependency 'rainbow', '~> 2.1.0'
  spec.add_dependency 'aws-sdk', '~> 3'
  spec.add_dependency 'camelizable', '~> 0.0.3'
  spec.add_dependency 'terminal-table', '~> 1'
end
