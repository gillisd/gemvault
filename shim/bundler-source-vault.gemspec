# frozen_string_literal: true

require_relative "../lib/gemvault/version"

Gem::Specification.new do |spec|
  spec.name    = "bundler-source-vault"
  spec.version = Gemvault::VERSION
  spec.authors = ["Author"]
  spec.summary = "Bundler source plugin for gemvault"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = ["plugins.rb"]
  spec.require_paths = ["."]

  spec.add_dependency "gemvault", "= #{Gemvault::VERSION}"
end
