require_relative "../lib/gemvault/version"

Gem::Specification.new do |spec|
  spec.name = "bundler-source-vault"
  spec.version = Gemvault::VERSION
  spec.authors = ["David Gillis"]
  spec.email = ["david@flipmine.com"]
  spec.summary = "Bundler source plugin for gemvault"
  spec.description = "Registers the :vault source type with Bundler, enabling gem installation from .gemv vault files"
  spec.homepage = "https://github.com/gillisd/gemvault"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.1"

  spec.files = ["plugins.rb"]
  spec.require_paths = ["."]

  spec.add_dependency "gemvault", "= #{Gemvault::VERSION}"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/gillisd/gemvault",
  }
end
