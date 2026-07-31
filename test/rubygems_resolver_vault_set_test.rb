require "test_helper"
require_relative "support/rubygems_source_vault_case"

class RubygemsResolverVaultSetTest < RubygemsSourceVaultCase
  MYGEM_FILES = { "lib/mygem.rb" => "module Mygem; end" }.freeze

  def test_find_all_matching
    results = find_all(name: "mygem", requirement: ">= 0")

    assert_equal 2, results.size
    assert(results.all?(Gem::Resolver::IndexSpecification))
    versions = results.map { |r| r.version.to_s }.sort

    assert_equal ["1.0.0", "2.0.0"], versions
  end

  def test_find_all_version_constraint
    results = find_all(name: "mygem", requirement: "~> 1.0")

    assert_equal 1, results.size
    assert_equal "1.0.0", results.first.version.to_s
  end

  def test_find_all_no_match
    results = find_all(name: "nonexistent", requirement: ">= 0")

    assert_empty results
  end

  private

  def build_fixture_vault
    gem_path = build_gem(name: "mygem", version: "1.0.0", dir: @gem_build_dir, files: MYGEM_FILES)
    gem2_path = build_subdir_gem(name: "mygem", version: "2.0.0", subdir: "gem2", files: MYGEM_FILES)
    populate_vault(path: @vault_path, gem_paths: [gem_path, gem2_path])
  end

  def find_all(name:, requirement:)
    set = Gem::Resolver::VaultSet.new(vault_source)
    req = Gem::Resolver::DependencyRequest.new(Gem::Dependency.new(name, requirement), nil)
    set.find_all(req)
  end
end
