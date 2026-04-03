# frozen_string_literal: true

require_relative "lib/gemvault/version"

Gem::Specification.new do |spec|
  spec.name          = "gemvault"
  spec.version       = Gemvault::VERSION
  spec.authors       = ["Author"]
  spec.summary       = "Multi-gem portable archives backed by SQLite"
  spec.description   = "SQLite-backed .gemv archives for bundling and distributing multiple gems as a single file"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["gemvault"]

  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "bundler", ">= 2.0"
  spec.add_dependency "command_kit", "~> 0.6"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
