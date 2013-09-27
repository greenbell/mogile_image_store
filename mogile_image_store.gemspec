# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mogile_image_store/version'

Gem::Specification.new do |spec|
  spec.name          = "mogile_image_store"
  spec.version       = MogileImageStore::VERSION
  spec.authors       = ["M.Shibuya"]
  spec.email         = ["m.shibuya@green-bell.jp"]
  spec.description   = %q{Rails plugin for using MogileFS as image storage}
  spec.summary       = %q{Rails plugin for using MogileFS as image storage}
  spec.homepage      = "https://github.com/greenbell/mogile_image_store"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mogilefs-client"
  spec.add_runtime_dependency "rails", "~> 3.0"
  spec.add_runtime_dependency "mime-types"
  spec.add_runtime_dependency "rmagick"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "cover_me"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "debugger"
  spec.add_development_dependency "factory_girl", "~> 1.3.2"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "sqlite3-ruby"
end
