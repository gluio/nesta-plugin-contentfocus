# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nesta-plugin-drop/version'

Gem::Specification.new do |spec|
  spec.name          = "nesta-plugin-drop"
  spec.version       = Nesta::Plugin::Drop::VERSION
  spec.authors       = ["Glenn Gillen"]
  spec.email         = ["me@glenngillen.com"]
  spec.summary       = %q{NestaCMS and Dropbox integration.}
  spec.description   = %q{Allows you to sync web content on Dropbox with a Ruby-based CMS}
  spec.homepage      = "https://nestadrop.io/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency 'nesta', '>= 0.10.0'
  spec.add_runtime_dependency 'rest-client'
  spec.add_runtime_dependency 'yajl-ruby'
end
