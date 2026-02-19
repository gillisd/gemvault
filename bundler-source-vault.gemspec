# frozen_string_literal: true

require_relative "lib/gemvault/version"

Gem::Specification.new do |spec|
  spec.name          = "bundler-source-vault"
  spec.version       = Gemvault::VERSION
  spec.authors       = ["Author"]
  spec.summary       = "Bundler plugin adding vault source for multi-gem .gemv archives"
  spec.description   = "Use SQLite-backed .gemv archives as Bundler sources containing multiple gems"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "plugins.rb", "LICENSE", "README.md", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["gemvault"]

  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "bundler", ">= 2.0"
  spec.add_dependency "command_kit", "~> 0.6"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
